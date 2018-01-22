<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>{{ site.github.project_title }} Appcast Feed</title>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        {% for release in site.github.releases %}
            {% if release.prerelease and page.prereleases %}{% break %}{% endif %}
            {% assign tag_name = release.tag_name %}
            {% assign release_prefix = "v/" %}
            {% unless release.tag_name contains release_prefix %}{% continue %}{% endunless %}
            {% assign version_nums = release.tag_name | remove_first: release_prefix | split: '/' %}
            {% assign version = version_nums[1] %}
            {% assign short_version = nil %}

            {% assign dmg_sign = nil %}
            {% assign body_lines = release.body | newline_to_br | split: '<br />' %}
            {% for line in body_lines %}
                {% if line contains "DMG Signature: " %}
                    {% assign dmg_sign = line | remove_first: "DMG Signature: " | strip %}
                {% endif %}
            {% endfor %}
            {% for asset in release.assets %}
                {% assign asset_ext = asset.browser_download_url | slice: -3, 3 %}
                {% if asset_ext != "dmg" %}{% break %}{% endif %}
                {% assign asset_url = asset.browser_download_url %}
                {% assign asset_size = asset.size %}
            {% endfor %}
            {% if asset_url %}
            <item>
                <title>{{ release.name }}</title>
                <description><![CDATA[{{ release.body | markdownify }}]]></description>
                <pubDate>{{ release.published_at | date_to_rfc822 }}</pubDate>
                <enclosure
                    url="{{ asset_url }}"
                    sparkle:version="{{ version }}"
                    {% if short_version %}sparkle:shortVersionString="{{ short_version }}"{% endif %}
                    length="{{ asset_size }}"
                    type="application/octet-stream"
                    {% if dmg_sign %}sparkle:dsaSignature="{{ dmg_sign }}"{% endif %}
                />
            </item>
            {% endif %}
        {% endfor %}
    </channel>
</rss>
