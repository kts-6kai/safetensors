
#  safetensors

See `app_safetensors.md`

URL?

```text

util.io/safetensors


```

```text
System Settings > General > Login Items & Extensions
```


## codex

```text
This folder contains a macOS app and an associated extension for a QuickLook Preview. The goal is a Viewer and QuickLook Preview for files with ".safetensors" extension. Implement the Plist files that I need and add comments (<!-- ... -->) describing what you add. Also add/modify .swift files as needed, but for now, just implement a most basic form of viewer: read the first 8 bytes as a u64-le and display a label with this value.


```



```
$ mdls -name kMDItemContentType -name kMDItemContentTypeTree /tmp/out.safetensors
kMDItemContentType     = "dyn.ah62d4rv4ge81g2pgqz4gn5xxr73hg"
kMDItemContentTypeTree = (
    "public.data",
    "public.item",
    "dyn.ah62d4rv4ge81g2pgqz4gn5xxr73hg"
)
```




```

qlmanage -r && qlmanage -r cache && killall Finder


```



```
"PreviewProvider" (was in PreviewProvider.swift)
- deleted
- we have QLIsDataBasedPreview == false



QLPreviewingController
For view based previews, the view controller that implements the QLPreviewingController protocol must at least implement one of the two following methods:

 -[QLPreviewingController preparePreviewOfSearchableItemWithIdentifier:queryString:completionHandler:],
 
 to generate previews for Spotlight searchable items.
 
 -[QLPreviewingController preparePreviewOfFileAtURL:completionHandler:],
 
to generate previews for file URLs.
```

## gen

```

fnd-defs type swiftlib gen --outfile /Users/kenschutte/Dropbox/repos/safetensors/generated.swift xcode_safetensors

```

## Icon

* drag 1024px into Assets.xcassets, AppIcon.
* ?

```
for s in 16 32 64 128 256 512 ; do echo $s ; convert /tmp/icon_1024.png -resize ${s}x${x} /tmp/icon_$s.png ; done
```
