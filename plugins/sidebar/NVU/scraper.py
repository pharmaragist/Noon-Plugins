#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "requests",
#   "httpx",
# ]
# ///

import asyncio
import json
import os
import re
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urljoin

import httpx
import requests

BASE = "https://lms.nv.edu.eg"
COOKIE_FILE = os.path.expanduser("~/.lms_cookies.json")
CACHE_DIR = os.path.expanduser("~/.lms_cache")
LMS_DATA_FILE = os.environ.get(
    "LMS_DATA_FILE", os.path.expanduser("~/.local/state/noon/lms_data.json")
)


def _cache(name):
    return os.path.join(CACHE_DIR, name + ".json")


def _read_cache(name):
    try:
        with open(_cache(name)) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _write_cache(name, data):
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(_cache(name), "w") as f:
        json.dump(data, f, ensure_ascii=False)


def save_cookies(sess):
    data = {c.name: c.value for c in sess.cookies}
    with open(COOKIE_FILE, "w") as f:
        json.dump(data, f)


def load_cookies(sess):
    try:
        with open(COOKIE_FILE) as f:
            data = json.load(f)
        for name, value in data.items():
            sess.cookies.set(name, value, domain="lms.nv.edu.eg")
        return True
    except (FileNotFoundError, json.JSONDecodeError):
        return False


def test_session(sess):
    try:
        r = sess.post(f"{BASE}/Questions/GetStudentCourses4", timeout=10)
        return r.status_code == 200 and len(r.json()) > 0
    except Exception:
        return False


def login_requests(student_id, password):
    sess = requests.Session()
    sess.headers.update(
        {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}
    )

    r = sess.get(f"{BASE}/login.aspx")

    class _Parser(HTMLParser):
        def __init__(self):
            super().__init__()
            self.hidden = {}

        def handle_starttag(self, tag, attrs):
            d = dict(attrs)
            if tag == "input" and d.get("type") in ("hidden",):
                name = d.get("name")
                value = d.get("value", "")
                if name:
                    self.hidden[name] = value

    p = _Parser()
    p.feed(r.text)

    payload = {
        "txtname": student_id,
        "txtPass": password,
        "Button1": "Login",
        "type": "1",
        **p.hidden,
    }

    r = sess.post(f"{BASE}/login.aspx", data=payload, allow_redirects=False)

    while r.status_code in (301, 302, 303, 307, 308):
        loc = r.headers.get("location", "")
        r = sess.get(urljoin(BASE, loc), allow_redirects=False)

    save_cookies(sess)
    return sess


def get_session(student_id, password):
    sess = requests.Session()
    sess.headers.update(
        {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}
    )

    if load_cookies(sess) and test_session(sess):
        return sess

    print("Logging in...", file=sys.stderr)
    sess = login_requests(student_id, password)
    return sess


class LMS:
    def __init__(self, student_id, password):
        self.id = student_id
        self.password = password
        self.sess = None
        self._login()

    def _login(self):
        self.sess = get_session(self.id, self.password)

    def download_file(self, url, output_path):
        if not url.startswith("http"):
            url = f"{BASE}{url}"
        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        resp = self.sess.get(url, timeout=120, allow_redirects=True)
        if len(resp.content) < 100:
            body = resp.text.strip()
            if "SessionError" in body:
                raise RuntimeError(f"Session error downloading {url}")
        tmp = output_path + ".part"
        with open(tmp, "wb") as f:
            f.write(resp.content)
        os.replace(tmp, output_path)

    def close(self):
        self.sess.close()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def get_materials(self, refresh=False):
        key = "materials"
        if not refresh:
            cached = _read_cache(key)
            if cached:
                return cached

        r = self.sess.get(f"{BASE}/ELearning/GetStudentElearningCourses")
        items = r.json()

        result = {}
        for item in items:
            course_key = f"{item['Code']} - {item['Name']}"
            if not item.get("FileId"):
                continue

            ext = (item.get("FileExtension") or "").lstrip(".")
            entry = {
                "file_id": item["FileId"],
                "file_name": item["FileName"],
                "file_type": ext,
                "size": str(item.get("FileSize", "")),
                "download_url": f"{BASE}/ELearning/DowloadFile?FileId={item['FileId']}",
                "week": item.get("WeekNumber", ""),
                "is_file": item.get("Type") == 0,
            }
            fullpath = item.get("FullPath") or ""
            if not entry["is_file"] and fullpath.startswith("http"):
                entry["external_url"] = fullpath
            result.setdefault(course_key, []).append(entry)

        _write_cache(key, result)
        return result

    def get_schedule(self, refresh=False):
        key = "schedule"
        if not refresh:
            cached = _read_cache(key)
            if cached:
                return cached

        r = self.sess.post(f"{BASE}/StudentSchedual/Report_StudentTable")
        items = r.json()

        r2 = self.sess.post(f"{BASE}/StudentSchedual/GetAllIntervals")
        iv = {i["IntervalId"]: i for i in r2.json()}

        day_map = {1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"}
        result = {}

        for item in items:
            day_name = day_map.get(item["DayWeek"])
            entries = result.setdefault(day_name, [])

            start = iv.get(item["IntervalId"])
            end = iv.get(item["IntervalId"] + item.get("IntervalsCount", 1) - 1)
            start_time = f"{start['TimeFrom']}-{start['TimeTo']}" if start else ""
            end_time = f"{end['TimeFrom']}-{end['TimeTo']}" if end else ""

            entries.append(
                {
                    "course": f"{item['Code']} - {item['Name']}",
                    "group": item.get("GroupName", ""),
                    "hall": item.get("ClassRoomName", ""),
                    "staff": item.get("Staff", ""),
                    "start_time": start_time,
                    "end_time": end_time,
                }
            )

        _write_cache(key, result)
        return result

    def get_grades(self, refresh=False):
        key = "grades"
        if not refresh:
            cached = _read_cache(key)
            if cached:
                return cached
        r = self.sess.post(f"{BASE}/GradeBook/StudentAssignmentsAndQuizes")
        data = r.json()
        result = {}

        for course in data:
            name = f"{course['Code']} - {course['CourseName']}"
            grades = [
                {
                    "activity_type": g["Type"],
                    "activity_name": g["QuizOrAssignName"],
                    "activity_grade": g["MaxGrade"],
                    "student_grade": g["StudentGrade"],
                    "student_percent": g["studentPercent"],
                    "student_status": g["StudentStatus"],
                    "attempts": g["AttemptsNo"],
                }
                for g in course.get("Data", [])
            ]
            if grades:
                result[name] = grades

        _write_cache(key, result)
        return result

    def get_question_bank(self, with_answers=False, refresh=False):
        key = "questions_with_answers" if with_answers else "questions"
        if not refresh:
            cached = _read_cache(key)
            if cached:
                return cached

        r = self.sess.post(f"{BASE}/Questions/GetStudentCourses4")
        courses = r.json()
        result = {}

        for course in courses:
            cid = course["CourseId"]
            name = f"{course['Code']} - {course['CourseName']}"

            r2 = self.sess.post(
                f"{BASE}/Questions/GetStduentQuestions", json={"CourseId": cid}
            )
            data = r2.json().get("Item1") or []

            questions = []
            for q in data:
                questions.append(
                    {
                        "question_id": q["QuestionId"],
                        "question_name": q.get("QuestionName", ""),
                        "question_type": q.get("QuestionTypeName", ""),
                        "question_text": q.get("QuestionText", ""),
                        "topic": q.get("topicName", ""),
                        "chapter": q.get("ChapterName", ""),
                        "default_mark": q.get("DefaultMark", 1),
                    }
                )

            if questions:
                result[name] = questions

        if with_answers:
            acookie = {c.name: c.value for c in self.sess.cookies}
            all_questions = [(subj, q) for subj, qs in result.items() for q in qs]

            async def fetch_all():
                headers = {
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
                }
                cookies = httpx.Cookies()
                for n, v in acookie.items():
                    cookies.set(n, v, domain="lms.nv.edu.eg")
                sem = asyncio.Semaphore(20)
                async with httpx.AsyncClient(
                    headers=headers, cookies=cookies, timeout=30
                ) as cl:

                    async def get_one(q):
                        async with sem:
                            try:
                                r3 = await cl.get(
                                    f"{BASE}/Questions/GetSharedQuestionData?QuestionId={q['question_id']}"
                                )
                                dl = (r3.json().get("Item1") or [{}])[0]
                                opts = dl.get("QuestionAnswer") or []
                                q["options"] = [
                                    {
                                        "text": o.get("OptionText", ""),
                                        "correct": o.get("GradePercentage", 0) == 100,
                                    }
                                    for o in opts
                                ]
                                q["default_mark"] = dl.get(
                                    "DefaultMark", q["default_mark"]
                                )
                            except Exception:
                                q["options"] = []

                    await asyncio.gather(*[get_one(q) for _, q in all_questions])

            try:
                asyncio.get_running_loop()
            except RuntimeError:
                asyncio.run(fetch_all())
            else:
                exc = []

                def _run():
                    try:
                        asyncio.run(fetch_all())
                    except Exception as e:
                        exc.append(e)

                import threading

                t = threading.Thread(target=_run, daemon=True)
                t.start()
                t.join()
                if exc:
                    raise exc[0]

        _write_cache(key, result)
        return result


def safe_name(s):
    return re.sub(r'[\\/:*?"<>|]', "_", s).strip()


EXT_MAP = {
    "pdf": "pdf",
    "pptx": "pptx",
    "jpg": "jpg",
    "png": "png",
    "docx": "docx",
    "xlsx": "xlsx",
    "avi": "mp4",
    "txt": "txt",
}


def target_name(f):
    fname = f.get("file_name") or f"file_{f['file_id']}"
    ext = EXT_MAP.get(f.get("file_type", ""), "")
    base_name = safe_name(fname)
    if ext and not base_name.endswith("." + ext):
        base_name += "." + ext
    return base_name


def dedupe_materials(files):
    seen = set()
    unique = []
    for f in files:
        key = target_name(f).lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(f)
    return unique


def file_bucket(f):
    name = (f.get("file_name") or "").lower()
    return "labs" if re.search(r"(?<![a-z])labs?(?![a-z])", name) else "lectures"


def download_materials(data, lms, outdir, workers=3):
    data = {subj: dedupe_materials(files) for subj, files in data.items()}
    root_dir = os.path.join(outdir, "NV_Materials")

    tasks = []
    for subject_name, files in data.items():
        subj_dir = os.path.join(root_dir, safe_name(subject_name))
        lab_dir = os.path.join(subj_dir, "labs")
        lec_dir = os.path.join(subj_dir, "lectures")
        os.makedirs(lab_dir, exist_ok=True)
        os.makedirs(lec_dir, exist_ok=True)
        for f in files:
            if not f.get("is_file", True):
                url = f.get("external_url")
                label = f"LINK {target_name(f)} -> {url}" if url else f"NOTE {target_name(f)}"
                print(label, file=sys.stderr)
                continue
            bin_dir = lab_dir if file_bucket(f) == "labs" else lec_dir
            tasks.append((f, os.path.join(bin_dir, target_name(f))))

    todo = []
    for f, path in tasks:
        if os.path.exists(path):
            print(f"SKIP {os.path.basename(path)}", file=sys.stderr)
        else:
            todo.append((f, path))

    total = len(todo)
    if not todo:
        print(f"\nSaved to {root_dir}", file=sys.stderr)
        return

    cookies = httpx.Cookies()
    for c in lms.sess.cookies:
        cookies.set(c.name, c.value, domain="lms.nv.edu.eg")
    headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}
    done = 0

    async def run():
        nonlocal done
        sem = asyncio.Semaphore(workers)
        async with httpx.AsyncClient(
            headers=headers, cookies=cookies, timeout=120, follow_redirects=True
        ) as cl:

            async def get_one(f, path):
                nonlocal done
                url = f["download_url"]
                if not url.startswith("http"):
                    url = f"{BASE}{url}"
                async with sem:
                    try:
                        tmp = path + ".part"
                        async with cl.stream("GET", url) as r:
                            r.raise_for_status()
                            with open(tmp, "wb") as fh:
                                async for chunk in r.aiter_bytes():
                                    fh.write(chunk)
                        if os.path.getsize(tmp) < 100:
                            with open(tmp, "rb") as fh:
                                body = fh.read().decode(errors="replace")
                            os.remove(tmp)
                            if "SessionError" in body or not body.strip():
                                raise RuntimeError(f"Session error downloading {url}")
                        os.replace(tmp, path)
                        done += 1
                        print(f"[{done}/{total}] {os.path.basename(path)}", file=sys.stderr)
                    except Exception as e:
                        print(f"  FAILED {os.path.basename(path)}: {e}", file=sys.stderr)

            await asyncio.gather(*[get_one(f, p) for f, p in todo])

    asyncio.run(run())
    print(f"\nSaved to {root_dir}", file=sys.stderr)


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print("Usage: scraper.py <command> [options]", file=sys.stderr)
        print(file=sys.stderr)
        print("Commands:", file=sys.stderr)
        print(
            "  lms-data        Fetch all data (materials, schedule, grades, questions) -> lms_data.json",
            file=sys.stderr,
        )
        print("  materials       Print materials JSON", file=sys.stderr)
        print("  schedule        Print schedule JSON", file=sys.stderr)
        print("  grades          Print grades JSON", file=sys.stderr)
        print(
            "  questions       Print question bank JSON (no answers)", file=sys.stderr
        )
        print(
            "  answers [--sub] Fetch answers for questions (optionally filter by subject)",
            file=sys.stderr,
        )
        print("  cache clear     Clear cached data", file=sys.stderr)
        print("  download [dir]  Download materials to directory", file=sys.stderr)
        print(file=sys.stderr)
        print("Options:", file=sys.stderr)
        print("  --refresh       Force refresh from server", file=sys.stderr)
        print(
            "  --sub NAME      Filter by subject name (answers only)", file=sys.stderr
        )
        return

    cmd = args[0]
    cmd_args = args[1:]

    refresh = "--refresh" in cmd_args or os.environ.get("LMS_REFRESH") == "1"

    if cmd == "cache":
        if cmd_args and cmd_args[0] == "clear":
            import shutil

            if os.path.exists(CACHE_DIR):
                shutil.rmtree(CACHE_DIR)
            if os.path.exists(LMS_DATA_FILE):
                os.remove(LMS_DATA_FILE)
            print("Cache cleared", file=sys.stderr)
        else:
            print("Usage: scraper.py cache clear", file=sys.stderr)
        return

    student_id = os.environ.get("LMS_ID", "6241447")
    password = os.environ.get("LMS_KEY", "XxXx_552006")

    with LMS(student_id, password) as lms:
        print("OK", file=sys.stderr)

        if cmd == "lms-data":
            data = {
                "materials": lms.get_materials(refresh=refresh),
                "schedule": lms.get_schedule(refresh=refresh),
                "grades": lms.get_grades(refresh=refresh),
                "questions": lms.get_question_bank(refresh=refresh),
            }
            os.makedirs(os.path.dirname(LMS_DATA_FILE), exist_ok=True)
            with open(LMS_DATA_FILE, "w") as f:
                json.dump(data, f, ensure_ascii=False)
            return

        if cmd == "schedule":
            print(
                json.dumps(
                    lms.get_schedule(refresh=refresh), indent=4, ensure_ascii=False
                )
            )
            return

        if cmd == "grades":
            print(
                json.dumps(
                    lms.get_grades(refresh=refresh), indent=4, ensure_ascii=False
                )
            )
            return

        if cmd == "questions":
            print(
                json.dumps(
                    lms.get_question_bank(refresh=refresh), indent=4, ensure_ascii=False
                )
            )
            return

        if cmd == "answers":
            sub = None
            for i, a in enumerate(cmd_args):
                if a == "--sub" and i + 1 < len(cmd_args):
                    sub = cmd_args[i + 1]

            data = lms.get_question_bank(refresh=refresh)
            if sub:
                sub_lower = sub.lower()
                data = {k: v for k, v in data.items() if sub_lower in k.lower()}

            if not data:
                print(json.dumps({}))
                return

            all_q = [(subj, q) for subj, qs in data.items() for q in qs]
            acookie = {c.name: c.value for c in lms.sess.cookies}

            async def _fetch():
                sem = asyncio.Semaphore(20)
                headers = {
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
                }
                cookies = httpx.Cookies()
                for n, v in acookie.items():
                    cookies.set(n, v, domain="lms.nv.edu.eg")
                async with httpx.AsyncClient(
                    headers=headers, cookies=cookies, timeout=30
                ) as cl:

                    async def get_one(q):
                        async with sem:
                            try:
                                r3 = await cl.get(
                                    f"{BASE}/Questions/GetSharedQuestionData?QuestionId={q['question_id']}"
                                )
                                dl = (r3.json().get("Item1") or [{}])[0]
                                opts = dl.get("QuestionAnswer") or []
                                q["options"] = [
                                    {
                                        "text": o.get("OptionText", ""),
                                        "correct": o.get("GradePercentage", 0) == 100,
                                    }
                                    for o in opts
                                ]
                                q["default_mark"] = dl.get(
                                    "DefaultMark", q["default_mark"]
                                )
                            except Exception:
                                q["options"] = []

                    await asyncio.gather(*[get_one(q) for _, q in all_q])

            asyncio.run(_fetch())

            existing = {}
            try:
                with open(LMS_DATA_FILE) as f:
                    existing = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            existing_questions = existing.get("questions", {})
            existing_questions.update(data)
            existing["questions"] = existing_questions
            os.makedirs(os.path.dirname(LMS_DATA_FILE), exist_ok=True)
            with open(LMS_DATA_FILE, "w") as f:
                json.dump(existing, f, ensure_ascii=False)

            print(json.dumps(data, indent=4, ensure_ascii=False))
            return

        if cmd == "download":
            outdir = None
            url = None
            positional = []
            i = 0
            while i < len(cmd_args):
                a = cmd_args[i]
                if a == "--dist" and i + 1 < len(cmd_args):
                    outdir = cmd_args[i + 1]
                    i += 2
                    continue
                if a == "--url" and i + 1 < len(cmd_args):
                    url = cmd_args[i + 1]
                    i += 2
                    continue
                if not a.startswith("-"):
                    positional.append(a)
                i += 1

            if outdir is None and positional:
                outdir = positional[0]
            if outdir is None:
                outdir = os.environ.get("LMS_OUTDIR", "lms_files")
            outdir = os.path.expanduser(outdir)

            if "--all" in cmd_args:
                data = lms.get_materials(refresh=refresh)
                download_materials(data, lms, outdir)
            elif url is not None:
                os.makedirs(outdir, exist_ok=True)
                resp = lms.sess.get(url, timeout=120, allow_redirects=True)
                if len(resp.content) < 100:
                    body = resp.text.strip()
                    if "SessionError" in body:
                        raise RuntimeError(f"Session error downloading {url}")
                cd = resp.headers.get("content-disposition", "")
                m = re.search(r'filename\*?=(?:UTF-8\'\')?["\']?([^"\';\n]+)', cd) if cd else None
                if m:
                    fname = safe_name(unquote(m.group(1)))
                else:
                    fid = re.search(r'FileId=(\d+)', url)
                    fname = f"file_{fid.group(1)}" if fid else "downloaded_file"
                    ext = re.search(r'\.(\w+)$', url)
                    if ext:
                        fname += "." + ext.group(1)
                path = os.path.join(outdir, safe_name(fname))
                print(f"Downloading {fname}...", file=sys.stderr)
                tmp = path + ".part"
                with open(tmp, "wb") as f:
                    f.write(resp.content)
                os.replace(tmp, path)
                print(f"Saved to {path}", file=sys.stderr)
            else:
                print("Usage: scraper.py download [--all | --url <url>] [--dist <dir>] [dir]", file=sys.stderr)
            return

        data = lms.get_materials(refresh=refresh)
        print(json.dumps(data, indent=4, ensure_ascii=False))


if __name__ == "__main__":
    main()
