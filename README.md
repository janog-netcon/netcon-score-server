NETCON Score Server
---

The contest site for [JANOG51 NETCON](https://www.janog.gr.jp/meeting/janog51).

It's called also *score server*.  The main feature of this is to propose problem and marking.

This provides whole game operations during contest:

- Proposing a problems (participant to solve in contest)
- Creating and discussing issues
- Submitting and marking answers
  - with a scoreboard
- Announcing notices

## Architecture, using frameworks

API and SPA

- API
  - Written in Ruby
  - Framework: Rails
    - Provides GraphQL API
- UI
  - Written in JavaScript
  - Framework: Nuxt.js(SPA)

#### Coding style

* [EditorConfig](http://editorconfig.org/): return code, indent, charset, and more
* [YAMLlint](https://github.com/adrienverge/yamllint): for YAML files
* [Rubocop](https://github.com/rubocop-hq/rubocop): for Ruby
* [ESLint](https://eslint.org/): for JavaScript


## Usage and How to Contribute

See [Wiki](https://github.com/ictsc/ictsc-score-server/wiki)

