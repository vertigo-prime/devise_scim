## Summary

<!-- What does this PR change, and why? The diff shows the what — focus on the why. -->

## Type

- [ ] Bug fix (includes a regression test)
- [ ] New feature (includes request spec in `spec/requests/`)
- [ ] SCIM protocol change
- [ ] Refactor / internal cleanup
- [ ] Documentation

## SCIM protocol reference

<!-- Required for SCIM protocol changes. Link to the relevant RFC section. -->
<!-- RFC 7643 — data model: https://www.rfc-editor.org/rfc/rfc7643 -->
<!-- RFC 7644 — protocol (endpoints, filters, PATCH): https://www.rfc-editor.org/rfc/rfc7644 -->

N/A

## Checklist

- [ ] `bundle exec rspec` — all examples pass
- [ ] `bundle exec rubocop` — no offenses
- [ ] `bundle exec brakeman --force --no-pager` — no warnings
- [ ] New feature: request spec added in `spec/requests/`
- [ ] Bug fix: regression test added that fails before the fix
- [ ] Filter system change: examples added to both `spec/filter/parser_spec.rb` and `spec/filter/arel_visitor_spec.rb`
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
