import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    clip: true
    color: "transparent"
    radius: Rounding.small

    property string searchQuery: ""
    property bool expanded
    property bool detached
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested

    PluginFileView {
        id: store
        fileName: "multi-feed"
        JsonAdapter {
            id: cfg
            property var feeds: []
        }
    }
    readonly property var d: store.data

    property var feedItems: []
    property bool loading: false
    property bool showFeeds: false
    property string filterFeed: ""

    function relativeTime(ts) {
        if (!ts || ts === 0) return "";
        var diff = Math.floor((Date.now() - ts) / 1000);
        if (diff < 60) return "now";
        if (diff < 3600) return Math.floor(diff / 60) + "m";
        if (diff < 86400) return Math.floor(diff / 3600) + "h";
        return Math.floor(diff / 86400) + "d";
    }

    function fetchAllFeeds() {
        var arr = d.feeds;
        if (!arr || arr.length === 0) { feedItems = []; loading = false; return; }
        loading = true;
        feedItems = [];
        var allItems = [];
        var done = 0;
        for (var i = 0; i < arr.length; i++) {
            var idx = i;
            fetchOne(arr[idx], allItems, function() {
                done++;
                if (done >= arr.length) {
                    allItems.sort(function(a, b) { return b.date - a.date; });
                    feedItems = allItems;
                    loading = false;
                }
            });
        }
    }

    function fetchOne(feed, out, cb) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", feed.url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) parseFeed(xhr.responseText, feed, out);
                if (cb) cb();
            }
        };
        xhr.send();
    }

    function parseFeed(xml, feed, out) {
        if (!xml) return;
        var re = /<item>([\s\S]*?)<\/item>/gi;
        var m;
        while ((m = re.exec(xml)) !== null) { var item = parseRssItem(m[1], feed); if (item) out.push(item); }
        re = /<entry[^>]*>([\s\S]*?)<\/entry>/gi;
        while ((m = re.exec(xml)) !== null) { var item = parseAtomEntry(m[1], feed); if (item) out.push(item); }
    }

    function parseRssItem(xml, feed) {
        var title = extract(xml, 'title');
        var link = extract(xml, 'link');
        var desc = extract(xml, 'description') || extract(xml, 'content:encoded');
        var pubDate = extract(xml, 'pubDate');
        var date = pubDate ? new Date(pubDate).getTime() : 0;
        if (!title && !link) return null;
        return { feedName: feed.name, title: clean(title), link: link, desc: clean(stripHtml(desc)), date: date, guid: extract(xml, 'guid') || link };
    }

    function parseAtomEntry(xml, feed) {
        var title = extract(xml, 'title');
        var link = extractAttr(xml, 'link', 'href');
        var summary = extract(xml, 'summary') || extract(xml, 'content');
        var published = extract(xml, 'published') || extract(xml, 'updated');
        var date = published ? new Date(published).getTime() : 0;
        if (!title && !link) return null;
        return { feedName: feed.name, title: clean(title), link: link, desc: clean(stripHtml(summary)), date: date, guid: extract(xml, 'id') || link };
    }

    function extract(xml, tag) {
        var re = new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)<\\/' + tag + '>', 'i');
        var m = xml.match(re);
        return m ? m[1].trim() : '';
    }

    function extractAttr(xml, tag, attr) {
        var re = new RegExp('<' + tag + '[^>]*' + attr + '="([^"]*)"', 'i');
        var m = xml.match(re);
        return m ? m[1].trim() : '';
    }

    function stripHtml(s) {
        return s ? s.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').trim() : '';
    }

    function clean(s) {
        if (!s) return '';
        return s.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&#x27;/g, "'");
    }

    function openLink(link) {
        if (link && link.indexOf("http") === 0) Qt.openUrlExternally(link);
    }

    function addFeed(name, url) {
        var arr = d.feeds.slice();
        arr.push({name: name, url: url});
        d.feeds = arr;
        fetchAllFeeds();
        showFeeds = false;
    }

    function removeFeed(idx) {
        var arr = d.feeds.slice();
        arr.splice(idx, 1);
        d.feeds = arr;
        feedItems = [];
    }

    function filteredItems() {
        var items = feedItems;
        if (filterFeed) items = items.filter(function(i) { return i.feedName === filterFeed; });
        if (searchQuery) {
            var q = searchQuery.toLowerCase();
            items = items.filter(function(i) {
                return (i.title && i.title.toLowerCase().indexOf(q) >= 0) || (i.desc && i.desc.toLowerCase().indexOf(q) >= 0);
            });
        }
        return items;
    }

    Component.onCompleted: fetchAllFeeds()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledRect {
            radius: Rounding.small
            color: Colors.colLayer0
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            RowLayout {
                anchors.fill: parent
                anchors.margins: Padding.small
                spacing: Padding.verysmall

                Symbol { icon: "rss_feed"; iconSize: 18; color: Colors.colPrimary }

                StyledText {
                    text: showFeeds ? "Manage" : (filterFeed ? filterFeed : "All Feeds")
                    font.pixelSize: Fonts.sizes.small
                    color: Colors.colOnSurface
                    Layout.fillWidth: true
                }

                Item { width: 1; visible: filterFeed !== ""
                    StyledRect {
                        anchors.centerIn: parent
                        width: 16; height: 16; radius: Rounding.full
                        color: Colors.colSecondaryContainer
                        StyledText {
                            anchors.centerIn: parent; text: "×"; font.pixelSize: 10
                            color: Colors.colOnSecondaryContainer
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: filterFeed = "" }
                }

                Symbol {
                    icon: showFeeds ? "rss_feed" : "playlist_add"
                    iconSize: 16; color: Colors.colOnSurfaceVariant
                    MouseArea { anchors.fill: parent; onClicked: showFeeds = !showFeeds }
                }

                Symbol {
                    icon: "refresh"
                    iconSize: 16
                    opacity: loading ? 0.4 : 1
                    color: Colors.colPrimary
                    MouseArea { anchors.fill: parent; onClicked: fetchAllFeeds() }
                }
            }
        }

        StyledListView {
            visible: !showFeeds
            Layout.fillWidth: true
            Layout.fillHeight: true
            _model: filteredItems()

            delegate: StyledRect {
                width: ListView.view.width
                height: 60
                color: Colors.colLayer1
                radius: Rounding.verytiny

                MouseArea {
                    anchors.fill: parent
                    onClicked: openLink(modelData.link)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.small
                    spacing: Padding.small

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        RowLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            StyledRect {
                                radius: Rounding.verytiny
                                color: Colors.colTertiaryContainer
                                height: 16
                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.feedName
                                    font.pixelSize: 9
                                    color: Colors.colOnTertiaryContainer
                                    anchors.leftMargin: 4; anchors.rightMargin: 4
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { filterFeed = modelData.feedName; mouse.accepted = true; }
                                }
                            }
                            StyledText {
                                text: relativeTime(modelData.date)
                                font.pixelSize: 9
                                color: Colors.colOnSurfaceVariant
                            }
                        }

                        StyledText {
                            text: modelData.title || "(no title)"
                            font.pixelSize: Fonts.sizes.small
                            color: Colors.colOnSurface
                            truncate: true
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: modelData.desc
                            font.pixelSize: 10
                            color: Colors.colOnSurfaceVariant
                            truncate: true
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            visible: modelData.desc !== ""
                        }
                    }

                    Symbol {
                        icon: "open_in_new"
                        iconSize: 12; color: Colors.colOnSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: feedItems.length === 0 && !loading
                text: d.feeds && d.feeds.length > 0 ? "No items — pull to refresh" : "Add a feed"
                color: Colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.centerIn: parent
                visible: loading
                text: "Loading..."
                color: Colors.colOnSurfaceVariant
            }
        }

        ColumnLayout {
            visible: showFeeds
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Padding.small
            Layout.margins: Padding.small

            StyledRect {
                radius: Rounding.small
                color: Colors.colLayer1
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.verysmall
                    spacing: Padding.verysmall

                    StyledTextField {
                        id: nameInput
                        placeholderText: "name"
                        Layout.preferredWidth: 70
                        Layout.maximumWidth: 70
                    }
                    StyledTextField {
                        id: urlInput
                        placeholderText: "https://example.com/feed.xml"
                        Layout.fillWidth: true
                    }
                    Symbol {
                        icon: "add_circle"
                        iconSize: 18; color: Colors.colPrimary
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var n = nameInput.text.trim();
                                var u = urlInput.text.trim();
                                if (n && u) { addFeed(n, u); nameInput.text = ""; urlInput.text = ""; }
                            }
                        }
                    }
                }
            }

            StyledText {
                text: "Subscribed Feeds"
                font.pixelSize: Fonts.sizes.tiny
                color: Colors.colOnSurfaceVariant
                visible: d.feeds && d.feeds.length > 0
            }

            StyledListView {
                _model: d.feeds
                Layout.fillWidth: true
                Layout.fillHeight: true

                delegate: StyledRect {
                    width: ListView.view.width
                    height: 40
                    color: Colors.colLayer0
                    radius: Rounding.verytiny

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Padding.small
                        spacing: Padding.small

                        Symbol { icon: "rss_feed"; iconSize: 14; color: Colors.colOnSurfaceVariant }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText {
                                text: modelData.name
                                font.pixelSize: Fonts.sizes.small
                                color: Colors.colOnSurface
                            }
                            StyledText {
                                text: modelData.url
                                font.pixelSize: 9
                                color: Colors.colOnSurfaceVariant
                                truncate: true
                                maximumLineCount: 1
                            }
                        }

                        Symbol {
                            icon: "delete"
                            iconSize: 16; color: Colors.colError
                            MouseArea {
                                anchors.fill: parent
                                onClicked: removeFeed(index)
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !d.feeds || d.feeds.length === 0
                    text: "No feeds"
                    color: Colors.colOnSurfaceVariant
                }
            }
        }
    }
}
