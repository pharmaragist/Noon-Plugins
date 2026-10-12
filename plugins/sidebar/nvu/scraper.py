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
import time
from html.parser import HTMLParser
from urllib.parse import unquote, urljoin

import httpx
import requests

BASE = "https://lms.nv.edu.eg"
COOKIE_FILE = os.path.expanduser("~/.lms_cookies.json")
CACHE_DIR = os.path.expanduser("~/.lms_cache")
LMS_DATA_FILE = os.environ.get(
    "LMS_DATA_FILE" or os.path.expanduser("~/.local/state/noon/lms_data.json")
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
        with open(output_path, "wb") as f:
            f.write(resp.content)

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
            }
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
            data = r2.json().get("Item1") or r2.json()

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


def download_materials(data, lms, outdir):
    total = sum(len(v) for v in data.values())
    done = 0

    for subject_name, files in data.items():
        subj_dir = os.path.join(outdir, safe_name(subject_name))
        os.makedirs(subj_dir, exist_ok=True)

        for f in files:
            done += 1
            fname = f.get("file_name") or f"file_{f['file_id']}"
            ext_map = {
                "pdf": "pdf",
                "pptx": "pptx",
                "jpg": "jpg",
                "png": "png",
                "docx": "docx",
                "xlsx": "xlsx",
                "avi": "mp4",
                "txt": "txt",
            }
            ext = ext_map.get(f["file_type"], "")
            base_name = safe_name(fname)
            if ext and not base_name.endswith("." + ext):
                base_name += "." + ext
            path = os.path.join(subj_dir, base_name)

            if os.path.exists(path):
                print(f"[{done}/{total}] SKIP {base_name}", file=sys.stderr)
                continue

            print(f"[{done}/{total}] {base_name}", file=sys.stderr)
            try:
                lms.download_file(f["download_url"], path)
                time.sleep(0.15)
            except Exception as e:
                print(f"  FAILED: {e}", file=sys.stderr)

    print(f"\nSaved to {outdir}", file=sys.stderr)


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
            dist_idx = None
            for i, a in enumerate(cmd_args):
                if a == "--dist" and i + 1 < len(cmd_args):
                    dist_idx = i
            if dist_idx is not None:
                outdir = cmd_args[dist_idx + 1]
                cmd_args = [a for i, a in enumerate(cmd_args) if i not in (dist_idx, dist_idx + 1)]
            else:
                outdir = os.environ.get("LMS_OUTDIR", "lms_files")

            if "--all" in cmd_args:
                data = lms.get_materials(refresh=refresh)
                download_materials(data, lms, outdir)
            elif "--url" in cmd_args:
                idx = cmd_args.index("--url")
                if idx + 1 >= len(cmd_args):
                    print("--url requires a URL argument", file=sys.stderr)
                    sys.exit(1)
                url = cmd_args[idx + 1]
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
                with open(path, "wb") as f:
                    f.write(resp.content)
                print(f"Saved to {path}", file=sys.stderr)
            else:
                print("Usage: scraper.py download --all | --url <url> [--dist <dir>]", file=sys.stderr)
            return

        data = lms.get_materials(refresh=refresh)
        print(json.dumps(data, indent=4, ensure_ascii=False))


if __name__ == "__main__":
    main()
