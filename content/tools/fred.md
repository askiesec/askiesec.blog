---
title: "fred url declutter"
date: "2026-03-21"
draft: false
tags: ["tools", "recon"]
---

# Fred URL Declutter

When doing URL recon for bug bounty, most of your list is noise. Wayback Machine and gau return everything they've ever seen for a domain — scanner payloads, tracking parameters, duplicate endpoints with different IDs, static assets. Before you can do anything useful with that list you need to clean it.

I built fred to handle this step.

## The Problem

Take a typical gau run against a target. You get 50k URLs back. Most of them are useless.

`/api/user/1`, `/api/user/2`, and `/api/user/9999` are the same endpoint. `/style.css` is not worth testing. `?utm_source=email` is not a parameter. Wayback also accumulates years of XSS payloads and scanner artifacts that people submitted to the site — those end up in your list too.

Running nuclei or ffuf against 50k URLs where 90% is noise wastes time and burns your IP.

## What fred Does

fred reads URLs from stdin and writes cleaned URLs to stdout. It sits between your collection tools and your scanners:

```bash
gau target.com | fred | nuclei -t fuzzing/
```

A few things happen under the hood:

**Structural deduplication.** Instead of comparing URLs literally, fred normalizes them first. `/api/user/123/posts` and `/api/user/456/posts` produce the same fingerprint — `target.com/api/user/{n}/posts` — so only one passes through. Same for UUIDs and hex hashes in paths.

**Noise filtering.** Paths with non-ASCII characters, embedded HTML tags, spaces after decoding, or concatenated URLs get rejected. These are virtually always Wayback artifacts, not real endpoints.

**Static asset filtering.** Images, fonts, stylesheets, media files, and archives are dropped before they reach your scanner.

**Tracking param removal.** `utm_source`, `fbclid`, `gclid`, and 20+ other tracking parameters are stripped from the output URL. They're never attack surface.

**Structural param awareness.** `?format=json` and `?format=xml` are treated as different endpoints because they likely return different content. `?id=1` and `?id=2` are not — only one representative passes through.

**Entropy analysis.** Parameter values with high Shannon entropy get flagged as potential exposed secrets and written to a separate file.

## Performance

On a list of 1 million URLs, all structurally identical:

```text
Time:   0.73s
Memory: ~1MB
CPU:    375% (4 cores)
```

Written in Go with a goroutine worker pool and `sync.Map` for lock-free deduplication. Scales linearly with core count.

## Install

```bash
go install github.com/askiesec/fred@latest
```

Or build from source:

```bash
git clone https://github.com/askiesec/fred
cd fred
go build -o fred .
```

## Usage

```bash
# basic cleanup
cat urls.txt | fred

# only URLs with query parameters
cat urls.txt | fred -p

# JSON output with metadata per URL
cat urls.txt | fred -f json

# write high-entropy params to a separate file
cat urls.txt | fred --secrets-out secrets.txt

# full pipeline
echo "target.com" | subfinder -silent \
  | httpx -silent \
  | gau --threads 5 \
  | fred --scope scope.txt --secrets-out secrets.txt \
  | nuclei -t fuzzing/ -rl 50
```

## Scope File

fred has a built-in scope engine. Create a plain text file:

```bash
# allow wildcards
*.target.com
target.com

# deny rules take priority — prefix with !
!target.com/logout
!*.target.com/static
```

Pass it with `--scope scope.txt` and out-of-scope URLs get filtered automatically. You can write them to a separate file with `--oos-file` if you want to audit them later.

## Real World Numbers

Running fred against a gau output for testphp.vulnweb.com:

```text
Input:       12,361 URLs
After fred:  ~400 URLs
```

Most of what got removed was Wayback garbage — scanner payloads, duplicated IDs, static assets. What's left is the actual attack surface of the application.

## Source

MIT license. Issues and PRs welcome.

[github.com/askiesec/fred](https://github.com/askiesec/fred)
