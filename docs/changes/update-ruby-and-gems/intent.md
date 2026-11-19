# Intent: update Ruby and gems to the latest minor

Status: accepted

Bump Ruby to the newest stable 4.0.x and every locked gem to its newest version within the current major, including the `rubocop-eirvandelden` git revision. No dependency is added or removed. Done when the tests, `ruby generate_themes.rb` and `bin/rubocop` are green and the generated output does not drift.
