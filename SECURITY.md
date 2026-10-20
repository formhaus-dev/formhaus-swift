# Security policy

## Supported versions

Security fixes go to the latest minor release of `formhaus-swift`. Older minors do not receive patches.

| Version | Supported |
|---|---|
| 0.1.x | Yes |

## Scope

`FormhausCore` runs on servers: `validateSubmission`, `checkDefinition`, the JSON parser and the regex engine take untrusted input. A way to make them accept values the definition rejects, crash, or run without bounds is a security issue. So is a way for `FormhausUI` to read files the user did not pick.

Bugs in rendering or layout are not security issues. Open a regular issue for them.

## Reporting a vulnerability

Report vulnerabilities privately through [GitHub security advisories](https://github.com/formhaus-dev/formhaus-swift/security/advisories/new). Do not open a public issue.

Include the version, a minimal definition or code that reproduces the problem, and the impact you expect.
