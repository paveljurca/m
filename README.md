# mQuery \[[Mediasite Video Platform](http://www.sonicfoundry.com/mediasite/)\]

Query Mediasite EVP (Enterprise Video Platform) Server for stored presentations (exclude Template and Player entity types) and check upon their relevant (video) streams like MP4, Slides (OCR), Smooth Streaming, Live Content, Audio and general playback.

__OUTPUT__

mQuery outputs [OneTab](https://www.one-tab.com/) import URL format for easy opening and maintenance

```
https://example.com/Mediasite/manage#module=Sf.Manage.PresentationSummary&args[id]=XXX | 2OP821:  2. week [AUDIO:good] [MP4:good] [OCR:bad] [PLAYBACK:bad] [SLIDES:bad]
https://example.com/Mediasite/manage#module=Sf.Manage.PresentationSummary&args[id]=XXX | 2OP821:  3. week [AUDIO:good] [MP4:good] [PLAYBACK:good] [SLIDES:good]
https://example.com/Mediasite/manage#module=Sf.Manage.PresentationSummary&args[id]=XXX | 2OP821:  4. week [AUDIO:good] [MP4:bad] [SS:good] [OCR:good] [PLAYBACK:good] [SLIDES:good]
```

__DEPENDENCY__

* [cURL](https://curl.haxx.se/download.html#Win32)

## Why?

There is no official interface yet it is a rudimentary task for anyone administering such a video platform to be aware of pending, working or missing video streams.

## SYNOPSIS

### Write env variables first

1. `M_AUTH`

  0. Open the Mediasite catalog in your favorite browser

  1. Alter the catalog URI to `/Mediasite/Manage` and log in

  2. From browser debugger copy `MediasiteAuth` cookie or inspect any XHR request for `Cookie` HTTP header

2. `M_HOST`

  [Mediasite Enterprise Video Platform Application](http://www.sonicfoundry.com/wp-content/uploads/2015/03/Mediasite-Video-Platform-7.0.29.pdf) (EVP) server [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) like `mediasite.example.com`

### Run mQuery like this

`( source auth.env && perl mQuery.pl --streams |tee mediasite.txt )`

## STREAMS

*Filter out streams*

* `grep -v [MP4] mediasite.txt` to list presentations missing an MP4 stream
* `grep [OCR:bad] mediasite.txt` to list presentations with a pending OCR
* `grep [PLAYBACK:bad] mediasite.txt` to list presentations with a broken playback (experimental)

## NOTES on audio

* Always check for not assigning a dummy audio interface (Recorder issue)

  Except a visual check there is *no way* to find a presentation is silent
  as for a *Completed* video stream there is always an audio layer
  present. And you cannot find about the audio size (length) unless you would
  download and demux the whole video file.

## RELEASE NOTES

mQuery wraps cURL requests around several Mediasite JSON URIs. Additionally it can be made to verify presentations for Status (Viewable/Scheduled/..), State (Completed/Pending/..) or Player (Multiview/Full experience/..).

- Tested for *Mediasite Server Version 7.0.30 Build 3737*
- There is *no possible support* for previous server versions

## TODO

- [x] replace [recursion](https://stackoverflow.com/a/15688105/1824796) with [iteration](http://blog.moertel.com/tags/recursion.html)
- [ ] start by a folder name (InitialFolderTree)
- [ ] replace system cURL with [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent)
- [ ] implement login instead of storing auth session cookie (expires in 15 minutes)

## LICENSE

Released into the public domain.

### DISCLAIMER

Don't blame me.
