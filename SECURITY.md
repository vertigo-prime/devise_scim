# Security Policy

`devise_scim` handles authentication and authorization for SCIM 2.0 endpoints — bearer token validation, OAuth 2.0 client-credentials flows, and tenant isolation. Security issues in this library can directly affect identity provisioning pipelines, so responsible disclosure is taken seriously.

## Supported Versions

This project is pre-1.0. Only the **latest released version** receives security fixes. There are no backport commitments to older patch or minor versions.

| Version | Supported |
| ------- | --------- |
| Latest `0.1.x` | ✅ |
| Older `0.1.x` | ❌ |

Once the gem reaches 1.0, the policy will be updated to cover the latest minor series.

## Scope

**In scope** — vulnerabilities in this gem's code:

- Bearer token validation bypass or timing attacks
- OAuth 2.0 client-credentials flow weaknesses
- Tenant isolation failures (cross-tenant data leakage in multi-tenant mode)
- SCIM filter injection or attribute exposure beyond configured mappings
- Authentication bypasses in `ScimAdapter` hooks
- Input validation gaps that allow privilege escalation via provisioned attributes
- RFC 7643 / RFC 7644 non-conformance that creates a security boundary violation

**Out of scope:**

- Vulnerabilities in your own application's Devise configuration
- Weaknesses in the identity provider (Okta, Azure AD, OneLogin, etc.)
- Issues requiring a misconfigured `devise_scim` initializer to reproduce (e.g., storing tokens in source control)
- General Rails or Devise security issues unrelated to SCIM handling

If you are unsure whether an issue is in scope, report it anyway — it will be evaluated.

## Reporting a Vulnerability

**Use GitHub's private vulnerability reporting.** Do not open a public issue.

1. Go to the [Security tab](https://github.com/vertigo-prime/devise_scim/security) of this repository.
2. Click **"Report a vulnerability"**.
3. Fill in: affected version(s), steps to reproduce, potential impact, and any suggested fix.

This opens a private channel visible only to the maintainer.

## Response Timeline

This is a solo-maintained project. Responses are best-effort, not guaranteed within a business SLA.

| Event | Target |
| ----- | ------ |
| Acknowledgement | Within 7 days |
| Severity assessment | Within 14 days |
| Patch for critical issues | Within 30 days |
| Patch for moderate issues | Within 60 days |

If a critical vulnerability has not received acknowledgement within 7 days, a follow-up in the private thread is welcome.

## Coordinated Disclosure

Please allow time to patch before any public disclosure. A 90-day window from initial report is the standard expectation. For critical issues with active exploitation, a shorter timeline can be negotiated — mention it in the report.

Once a fix is released, credit will be given in the CHANGELOG and release notes unless anonymity is requested.
