# Speed up Docker for Mac

Docker bind mounts are notoriously slow on macOS as soon as the project contains
a lot of small files (see [docker/for-mac#77](https://github.com/docker/for-mac/issues/77)).
This repo demonstrates how to keep near-native performance by using
[Mutagen](https://mutagen.io/) to synchronize the codebase between the host and
a Docker named volume, integrated with Compose via `mutagen-compose`.

The example app is a small Symfony 6.4 / PHP 8.3 / MariaDB 11 stack, but the
approach is language-agnostic.

## Quick start

### Prerequisites

- Docker with Compose v2
- macOS only: [Mutagen](https://mutagen.io/) + `mutagen-compose`
  ```sh
  brew install mutagen-io/mutagen/mutagen mutagen-io/mutagen/mutagen-compose
  ```

### Start the stack

```sh
make up         # auto-selects mutagen-compose on macOS, plain docker compose on Linux
make install    # composer install + migrations + fixtures
open http://localhost
```

Under the hood, `make up` resolves to:
- **Linux**: `docker compose up -d --build` (bind mount, already fast)
- **macOS**: `mutagen-compose -f compose.yaml -f compose.mac.yaml up -d --build`
  (named volume + Mutagen sync session)

You can override the choice with `COMPOSE="docker compose" make up` if you want
to bypass Mutagen on macOS for comparison.

## Verifying it works

### Functional check

`make check-sync` writes a sentinel file on each side and confirms it appears
on the other within the timeout. Both directions must succeed:

```
$ make check-sync
host -> container... OK in 1s
container -> host... OK in 1s
Sync is functional in both directions.
```

On macOS, `make sync-status` shows the live Mutagen session and any conflicts:

```
$ make sync-status
Name: code
Identifier: sync_xxx
Status: Watching for changes
```

### Performance benchmark

`make bench` times a few realistic workloads inside the container. Run it twice
on macOS, once with Mutagen and once without, to see the gap:

```sh
# With Mutagen (default on macOS)
make bench

# Same stack, plain bind mount (no Mutagen)
COMPOSE="docker compose" make bench
```

The script measures: full filesystem walk, cold `composer install`, Symfony
cache warmup, and a 1000-tiny-files write. The Mutagen run should be several
times faster on the write-heavy workloads on a project of any meaningful size.
For reference, Docker reports [2–10× speedups for the equivalent technique][docker-sfs-blog]
in their own benchmarks.

[docker-sfs-blog]: https://www.docker.com/blog/announcing-synchronized-file-shares/

## Repo layout

```
compose.yaml           Base stack, works as-is on Linux, fallback on Mac
compose.mac.yaml       Override: named volume + x-mutagen sync session
docker/
  nginx/               nginx config (mounted into nginx:alpine)
  php-fpm/             PHP 8.3 FPM image (intl, opcache, pdo_mysql, zip)
scripts/
  check-sync.sh        Functional sync test
  benchmark.sh         Performance benchmark
Makefile               Convenience targets (up, install, bench, sync-status, …)
app/                   Symfony 6.4 example app
```

The Mutagen sync is declared at the bottom of `compose.mac.yaml`:

```yaml
x-mutagen:
  sync:
    code:
      alpha: "./app"
      beta: "volume://code"
      mode: "two-way-resolved"
```

`x-` keys are ignored by plain `docker compose`, so the same files stay valid
when running without Mutagen.

## Alternatives worth knowing

| Option | Cost | Notes |
| --- | --- | --- |
| **Plain bind mount + VirtioFS** (Docker Desktop default) | free | [~3× slower than native][mainardi-2025]; OK for small projects, struggles on tools that walk many files. |
| **Mutagen + mutagen-compose** (this repo) | free | Near-native speed. Adds a daemon and one extra command to install. |
| **Docker Desktop "Synchronized file shares"** | [paid (Pro/Teams/Business)][docker-sfs-pricing] | Docker's own, integrated re-implementation of the same idea, set up in the [Docker Desktop UI][docker-sfs-docs] rather than via compose. |
| **OrbStack** | free for personal use, paid for commercial | [Drop-in Docker Desktop replacement][orbstack-compare] with two-way file sharing built in; often reported as fast as Mutagen with no extra tooling. |

[mainardi-2025]: https://www.paolomainardi.com/posts/docker-performance-macos-2025/
[docker-sfs-pricing]: https://www.docker.com/pricing/
[docker-sfs-docs]: https://docs.docker.com/desktop/features/synchronized-file-sharing/
[orbstack-compare]: https://docs.orbstack.dev/compare/docker-desktop

## Non-root user inside the container

If your container runs as a non-root user, set permissions on the Mutagen sync
in `compose.mac.yaml`:

```yaml
x-mutagen:
  sync:
    code:
      # ...
      configurationBeta:
        permissions:
          defaultFileMode: 0644
          defaultDirectoryMode: 0755
          defaultOwner: "appuser"
          defaultGroup: "appuser"
```

## Further reading

- [Mutagen Compose documentation](https://mutagen.io/documentation/orchestration/compose/), the `x-mutagen` extension guide.
- [Docker on macOS is still slow? (Paolo Mainardi, 2025)](https://www.paolomainardi.com/posts/docker-performance-macos-2025/), recent benchmark across Docker VMM, OrbStack, Lima, and native Linux.
- [VirtioFS is 4× faster than gRPC-FUSE (Jeff Geerling, 2022)](https://www.jeffgeerling.com/blog/2022/new-docker-mac-virtiofs-file-sync-4x-faster/), early benchmark when VirtioFS shipped as an experimental feature.
- [Improving performance for Docker on Mac when using named volumes (netresearch)](https://medium.com/netresearch/improving-performance-for-docker-on-mac-computers-when-using-named-volumes-55580efcbf68#bf1b), the original Mutagen vs alternatives benchmark.
- [docker/for-mac#77](https://github.com/docker/for-mac/issues/77), the upstream issue tracking shared-volume performance on macOS.
