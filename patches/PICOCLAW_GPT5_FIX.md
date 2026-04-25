# PicoClaw `openai/gpt-5-nano` Fix Notes

## Summary

This document explains what was broken in this PicoClaw setup, how the issue was diagnosed, what code was changed, how the binaries were rebuilt and replaced, and what lessons to take away from the debugging process.

This was not a simple "bad API key" problem.

The real issue was a chain of backend compatibility bugs:

1. PicoClaw selected `openai/gpt-5-nano` in the UI.
2. But the backend incorrectly routed that model to the Codex / ChatGPT backend.
3. After fixing that routing bug, the backend hit two more OpenAI API compatibility problems:
   - it injected unsupported built-in web search tool types
   - it sent an unsupported non-default `temperature` value to `gpt-5-nano`

After patching those issues and rebuilding the binaries, PicoClaw began working normally.

## Environment

Relevant paths:

- PicoClaw home: `/home/mq/.picoclaw`
- Installed binaries: `/home/mq/pico_iot/picoclaw` and `/home/mq/pico_iot/picoclaw-launcher`
- Source checkout created during debugging: `/home/mq/pico_iot/picoclaw-src`

Relevant services:

- Launcher UI: `http://localhost:18800`
- Gateway health endpoint: `http://127.0.0.1:18790/health`

## Initial Symptom

In the browser UI, the selected model was clearly shown as:

`openai/gpt-5-nano`

But sending even a simple message like `hi` produced:

`codex API call: POST "https://chatgpt.com/backend-api/codex/responses": 401 Unauthorized`

This was the first strong clue that the selected model and the actual backend transport did not match.

## Why That Error Was Suspicious

If PicoClaw were truly using the normal OpenAI API for `openai/gpt-5-nano`, the request should have gone to:

`https://api.openai.com/v1/...`

Instead, it went to:

`https://chatgpt.com/backend-api/codex/responses`

That is a different backend, with different auth expectations.

This meant:

- the UI model selector was not the real source of truth for request routing
- the backend binary was making an internal provider decision that overrode the expected API path

## Step 1: Verify Local Config and Credentials

The first check was to make sure the local PicoClaw config was not obviously wrong.

Files inspected:

- `/home/mq/.picoclaw/config.json`
- `/home/mq/.picoclaw/auth.json`
- `/home/mq/.picoclaw/.security.yml`

Important findings:

1. `config.json` already had the default model set to `openai/gpt-5-nano`.
2. `auth.json` contained an OpenAI token.
3. `provider` and `auth_method` needed cleanup so the local config more clearly expressed "use OpenAI token auth".

Local config fixes applied:

- set default provider to `openai`
- ensured `openai/gpt-5-nano` had `auth_method: "token"`
- added a matching security entry for `openai/gpt-5-nano`
- removed unrelated OAuth-only model entries that could trigger alternate auth paths

Those changes were necessary, but they were not sufficient.

## Step 2: Prove the Bug Was in the Binary, Not the Browser

To avoid guessing based on the web UI, PicoClaw was tested directly from the command line:

```bash
printf 'hi\n' | /home/mq/pico_iot/picoclaw agent
```

This reproduced the same failure outside the browser.

That was a key moment in the debugging process.

It proved:

- the issue was not a browser caching problem
- the issue was not just the launcher UI
- the installed `picoclaw` binary itself was routing requests incorrectly

## Step 3: Identify the Installed Binary and Running Processes

Running processes were checked:

```bash
ps -ef | grep picoclaw | grep -v grep
```

This showed the actual launcher and gateway were using:

- `/home/mq/pico_iot/picoclaw-launcher`
- `/home/mq/pico_iot/picoclaw`

That mattered because fixing files in `/home/mq/.picoclaw` alone would not be enough if the binary logic itself was wrong.

## Step 4: Inspect the Binary and Source Clues

The installed binary was only a compiled executable, not a source checkout.

Using `strings` on the binary showed several important clues:

- embedded module path: `github.com/sipeed/picoclaw`
- embedded Codex endpoint strings
- mixed support for OpenAI API keys, OAuth, Codex, and other providers

That gave enough confidence to fetch the actual upstream source.

## Step 5: Clone the Source and Prepare the Build Toolchain

Source was cloned to:

`/home/mq/pico_iot/picoclaw-src`

At that point the machine did not have Go installed.

That was handled by installing the build dependencies directly:

```bash
sudo apt-get update
sudo apt-get install -y golang-go
sudo npm install -g pnpm
```

This is an important lesson: not being able to build from source usually means "missing toolchain", not "impossible". Once the missing build tools are installed, the rest becomes much more approachable.

## Step 6: Build the Project and Reproduce the Bug in Fresh Source

The project was built from source using:

```bash
make build
make build-launcher
```

Even a fresh upstream build still reproduced the Codex error.

That was valuable because it proved the issue was not caused by some local corruption in your old binary. The behavior was coming from upstream source logic.

## Step 7: Find the Real Routing Bug in Source Code

The critical file was:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/factory_provider.go`

The bad logic was in the `openai` branch of `CreateProviderFromConfig`.

It effectively treated both:

- `auth_method: "oauth"`
- `auth_method: "token"`

as reasons to create the Codex provider.

That was the root bug.

For your setup:

- model: `openai/gpt-5-nano`
- auth method: `token`

PicoClaw should have used the normal OpenAI HTTP API provider.

Instead, it created the Codex provider and sent requests to:

`https://chatgpt.com/backend-api/codex`

## Step 8: Patch Provider Routing

The first source fix was:

- file: `/home/mq/pico_iot/picoclaw-src/pkg/providers/factory_provider.go`

What changed:

1. `oauth` auth still routes to the Codex provider.
2. `token` auth now routes to the normal OpenAI-compatible HTTP provider.

This was implemented by introducing a helper that reads the stored OpenAI credential and constructs the regular HTTP provider with:

- the OpenAI token as the bearer token
- the normal OpenAI API base URL

Tests were added and updated in:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/factory_test.go`

These tests now verify:

- OpenAI token auth returns `HTTPProvider`
- OpenAI OAuth returns `CodexProvider`

## Step 9: Rebuild and Discover the Next Error

After rebuilding with the routing fix, the Codex error disappeared.

That was real progress.

The next failure became:

`Invalid value: 'web_search_preview'. Supported values are: 'function' and 'custom'.`

This was actually good news. It meant requests were now hitting the standard OpenAI API path instead of Codex.

The system had advanced to the next incompatibility.

## Step 10: Understand the Web Search Tool Injection Bug

The next critical file was:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider.go`

The provider was injecting built-in native search tool definitions into the request body.

It first used:

- `web_search_preview`

Then after trying a more current name, it still failed with:

- `web_search`

The API response clearly said the `chat/completions` endpoint used here only supports:

- `function`
- `custom`

So the real lesson was:

This provider path should not inject any built-in web search tool type at all.

Instead, PicoClaw should rely on its own client-side `web_search` tool system.

## Step 11: Patch OpenAI-Compatible Provider Tool Behavior

The next source fix was in:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider.go`

What changed:

1. Native search injection was disabled for this provider.
2. `SupportsNativeSearch()` now returns `false`.
3. The request body only includes tools that are standard function tools.

This prevents invalid tool types from reaching the OpenAI API.

Related tests were updated in:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider_test.go`

The tests now reflect the correct behavior:

- no built-in native search tool is injected for this provider
- client-side tools pass through normally

## Step 12: Rebuild and Discover the Final Error

After the native-search patch, the next failure was:

`Unsupported value: 'temperature' does not support 0.7 with this model. Only the default (1) value...`

This was the last major compatibility issue.

Again, this was a useful signal:

- the request path was now correct
- tool format was now correct
- only a model-specific parameter rule remained

## Step 13: Patch GPT-5 Temperature Handling

Still in:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider.go`

The request-building logic was changed so that for `gpt-5` models:

- `temperature` is omitted entirely

Why omit instead of forcing `1`?

Because the error message indicated the model only accepts the default behavior. Omitting the parameter is the safest way to preserve that default and avoid sending unsupported values inherited from generic defaults.

## Step 14: Rebuild, Replace Binaries, and Restart

After each successful patch and test pass, the main binary was rebuilt:

```bash
make build
```

The launcher had already been rebuilt earlier:

```bash
make build-launcher
```

Then the new binaries replaced the installed ones:

- `/home/mq/pico_iot/picoclaw`
- `/home/mq/pico_iot/picoclaw-launcher`

The original binaries were backed up first.

The launcher and gateway were then restarted.

Detached startup that worked reliably:

```bash
setsid /home/mq/pico_iot/picoclaw-launcher -no-browser /home/mq/.picoclaw/config.json >/home/mq/.picoclaw/logs/manual-launcher.out 2>&1 < /dev/null &
```

This was used because simple `nohup` startup was not consistently staying alive in the non-interactive shell environment.

## Step 15: Verify the Fix End to End

Health check:

```bash
curl -sS http://127.0.0.1:18790/health
```

Direct assistant smoke test:

```bash
printf 'hi\n' | /home/mq/pico_iot/picoclaw agent
```

Final successful output:

`Hi! How can I help you today?`

That confirmed:

- no Codex routing
- no tool schema mismatch
- no temperature mismatch
- successful end-to-end model response

## Source Files Changed

Primary logic changes:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/factory_provider.go`
- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider.go`

Tests changed:

- `/home/mq/pico_iot/picoclaw-src/pkg/providers/factory_test.go`
- `/home/mq/pico_iot/picoclaw-src/pkg/providers/openai_compat/provider_test.go`

Supporting local config cleanup:

- `/home/mq/.picoclaw/config.json`
- `/home/mq/.picoclaw/.security.yml`

## What You Should Learn From This

### 1. Read the actual failing URL

The failing URL often tells you more than the error message itself.

In this case:

- expected: `api.openai.com`
- actual: `chatgpt.com/backend-api/codex`

That immediately suggested a backend routing problem, not a normal API key problem.

### 2. Reproduce outside the UI

Whenever possible, reproduce the failure without the browser:

```bash
printf 'hi\n' | /path/to/picoclaw agent
```

If the CLI reproduces the same error, the problem is deeper than the UI.

### 3. Fix one error at a time

This debug session had multiple stacked issues.

If we had stopped at the first fix, PicoClaw still would not have worked.

The sequence was:

1. wrong provider routing
2. wrong tool type injection
3. wrong temperature parameter

This is common in integration bugs: the first visible error may hide the next one.

### 4. Use tests to lock in behavior

Each patch was safer because tests were added or updated alongside the logic.

That matters because provider logic is subtle and easy to break again later.

### 5. Building from source is mostly about toolchain and patience

At the start, the machine did not even have Go installed.

That can feel like a blocker, but it usually is not.

The pattern is:

1. find the source
2. read the build instructions
3. install missing tools
4. build
5. run
6. patch
7. rebuild
8. verify

Once you can do that loop, you can fix a surprising number of real-world problems.

## Commands That Were Most Useful

Find running PicoClaw processes:

```bash
ps -ef | grep picoclaw | grep -v grep
```

Direct assistant smoke test:

```bash
printf 'hi\n' | /home/mq/pico_iot/picoclaw agent
```

Health check:

```bash
curl -sS http://127.0.0.1:18790/health
```

Build core binary:

```bash
cd /home/mq/pico_iot/picoclaw-src
make build
```

Build launcher:

```bash
cd /home/mq/pico_iot/picoclaw-src
make build-launcher
```

Run focused provider tests:

```bash
go test ./pkg/providers
go test ./pkg/providers/openai_compat
```

Restart launcher robustly:

```bash
setsid /home/mq/pico_iot/picoclaw-launcher -no-browser /home/mq/.picoclaw/config.json >/home/mq/.picoclaw/logs/manual-launcher.out 2>&1 < /dev/null &
```

## Current Working State

The current installed PicoClaw now works with:

- model: `openai/gpt-5-nano`
- transport: standard OpenAI API path
- launcher: rebuilt local launcher binary
- gateway: healthy and responding

The browser UI at `http://localhost:18800` should now send messages successfully.

## Recommendation

To preserve this work, the next good step would be to commit the patched source tree in:

`/home/mq/pico_iot/picoclaw-src`

That way:

- you keep a record of the fix
- you can rebuild again later
- you do not lose the patch during future updates

## Final Takeaway

The most important lesson is this:

When a system says it is using one model but behaves like it is using another backend, trust the observed request path over the UI.

In this case, the UI said `gpt-5-nano`, but the backend behavior said `Codex`.

Following the evidence step by step revealed the true bugs, and fixing them in source made the installation actually work.
