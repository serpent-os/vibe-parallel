**This project is no longer active**

---

# vibe-parallel

A simple DLang module providing `foreach` construct based on a set of fibers.
Highly useful for scope-controlled fetch operations and other asynchronous I/O.

Primary purpose is for use with batched downloads in Serpent OS tooling which need
coupling with progressbars for visual feedback.

Note: This is not officially endosred by the `vibe.d` project

## Example

```d
import vibe.parallel;

auto uris = ...;
foreach (uri, idx; uris.fiberParallel)
{
    uri.download(uri.baseName);
}
```

# License

Available under the terms of the Zlib software license.
