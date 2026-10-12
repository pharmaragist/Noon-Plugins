pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils

Singleton {
    id: root

    property var allIcons: []
    property string searchQuery: ""

    FileView {
        id: iconsFile
        path: Paths.plugins.sidebar + "/M3Icons/m3iconsDB.json"
        onTextChanged: {
            const raw = JSON.parse(iconsFile.text());
            const icons = [];
            const entries = Object.entries(raw);
            for (let i = 0; i < entries.length; i++) {
                const entry = entries[i];
                const name = entry[0];
                const data = entry[1];
                icons.push({
                    name: name,
                    tags: data.tags || []
                });
            }
            root.allIcons = icons;
        }
    }

    function filterIcons(query) {
        let result = root.allIcons;
        const q = query.toLowerCase().trim();
        if (q) {
            const filtered = [];
            for (let i = 0; i < result.length; i++) {
                const icon = result[i];
                if (icon.name.toLowerCase().includes(q)) {
                    filtered.push(icon);
                    continue;
                }
                const tags = icon.tags;
                let matched = false;
                for (let j = 0; j < tags.length; j++) {
                    if (tags[j].toLowerCase().includes(q)) {
                        matched = true;
                        break;
                    }
                }
                if (matched) {
                    filtered.push(icon);
                }
            }
            result = filtered;
        }
        return result;
    }
}
