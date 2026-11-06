# Security Policy

**English** · [Русский](SECURITY.ru.md) · [Українська](SECURITY.uk.md)

## Supported versions

Only the latest version of Cibula receives fixes. Please update before
reporting a problem.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Use GitHub's private reporting instead: open the **Security** tab of this
repository and choose **Report a vulnerability**.

Please include:

- what the problem is and what an attacker could do with it,
- steps to reproduce it,
- your iOS version and device,
- the Cibula version (Settings, bottom of the screen).

Cibula is maintained by one person in their free time. I will try to answer
within about a week, but I can't promise a fixed timeline. Reporters who want
to be credited will be named in the release notes once a fix is out.

## Scope

In scope: code and build configuration that is specific to Cibula (interface,
settings, the build scripts in this repository).

Out of scope, please report these upstream:

- Problems in the Tor network or the Tor software: The Tor Project
  (https://www.torproject.org/).
- Problems that also exist in the original app: Onion Browser
  (https://github.com/OnionBrowser/OnionBrowser).

## Known limitations

Please keep these in mind before relying on Cibula:

- Cibula always uses the Tor client that is built into the app. The upstream
  project warns that this mode has security limitations compared to running
  Tor through Orbot.
- Tor on iOS can't offer all the protections of the desktop Tor Browser.
- Cibula is an unofficial fork and has not been independently audited.
- Tor does not make you anonymous by itself. What you do on a website still
  matters (logins, personal details, downloads).

If your safety depends on strong anonymity, use the official Tor Browser.

## Installing safely

Only install builds that you compiled yourself from this repository, or builds
published in this repository's releases or in the official Telegram channel
linked in the README. Don't install copies from other sources.
