# Plan: update Ruby and gems to the latest minor

Status: accepted

1. Write `4.0.9` to `.ruby-version`.
2. Run `bundle update --minor`.
3. Run `ruby generate_themes.rb` and check `git diff` for output drift.
4. Run the three test files and `bin/rubocop`.
5. Commit `.ruby-version` and `Gemfile.lock` as one commit.
