# Changelog

## [0.5.0](https://github.com/seuros/active_project/compare/active_project/v0.4.0...active_project/v0.5.0) (2025-12-14)


### Features

* add Fizzy adapter ([94d8a13](https://github.com/seuros/active_project/commit/94d8a13e4829e1c7b74e6ed94f848491587932be))


### Bug Fixes

* prevent VCR cassette modifications during test runs ([f6aa7df](https://github.com/seuros/active_project/commit/f6aa7df9152607a717734bbb6b02867daf3b25ba))
* resolve adapter context issues and add missing error classes ([a831d08](https://github.com/seuros/active_project/commit/a831d0860b7e8436869cea14374f0f884b001d36))
* resolve async deadlock in tests with async-safe ([f4b23fa](https://github.com/seuros/active_project/commit/f4b23faaa24a836665bc5ee363d5898e43746646))

## [0.4.0](https://github.com/seuros/active_project/compare/active_project/v0.3.0...active_project/v0.4.0) (2025-12-11)


### Features

* Add Support for Github Issues with Repo Mapping to Project ([#8](https://github.com/seuros/active_project/issues/8)) ([e79bc39](https://github.com/seuros/active_project/commit/e79bc39e3903c65e5ecd5d3b8cf032c7e11fa510))
* GithubProjects  adapter. ([#13](https://github.com/seuros/active_project/issues/13)) ([a3a7b02](https://github.com/seuros/active_project/commit/a3a7b02f0aa54c861e8d954905acab6550598eaa))


### Bug Fixes

* rename github =&gt; github_repo ([59432f3](https://github.com/seuros/active_project/commit/59432f329de82a464b177c418246147c87077a2e))

## [0.3.0](https://github.com/seuros/active_project/compare/active_project/v0.2.0...active_project/v0.3.0) (2025-04-23)


### Features

* **core:** introduce Async I/O pathway ([f9bdb08](https://github.com/seuros/active_project/commit/f9bdb08a61bac2c92a6eff6a65ddc2dfac6d9ace))
* **core:** introduce Async I/O pathway ([3e34ea0](https://github.com/seuros/active_project/commit/3e34ea0d41c00b59ddfb69a6347e3ea70ae37b44))
* **rails:** auto-install Async::Scheduler via Railtie ([3ec331f](https://github.com/seuros/active_project/commit/3ec331ff02a71305b84523409529d96ea9325551))

## [0.2.0](https://github.com/seuros/active_project/compare/active_project/v0.1.1...active_project/v0.2.0) (2025-04-10)


### Features

* allow deletion of issues ([8758a36](https://github.com/seuros/active_project/commit/8758a363ae3048abdc9e2192f2980bfb5815c82d))
* allow deletion of issues ([5adee6b](https://github.com/seuros/active_project/commit/5adee6b698c5487569fbe4ef13512a2ea065fa9a))
* **jira:** allow creations of sub-tasks ([5adee6b](https://github.com/seuros/active_project/commit/5adee6b698c5487569fbe4ef13512a2ea065fa9a))

## [0.1.1](https://github.com/seuros/active_project/compare/active_project/v0.1.0...active_project/v0.1.1) (2025-04-10)


### Bug Fixes

* alias new to build for collection ([2e0fe5a](https://github.com/seuros/active_project/commit/2e0fe5a24157f94a8692b46aa8e23d241a504d97))
* improve code structure. ([ac31d10](https://github.com/seuros/active_project/commit/ac31d10582896d7c46bb9e9d8acbdeb25b62d624))
* split adapters into smaller modules ([bc45b04](https://github.com/seuros/active_project/commit/bc45b04d548b8fd5df8dd4988edf42024403fa63))

## 0.1.0 (2025-04-09)


### Features

* allow multiple to connect to multiple instance of the same api. ([179b548](https://github.com/seuros/active_project/commit/179b5481b99da79a61e7322454b21aa452c25810))
* allow multiple to connect to multiple instance of the same api. ([f1b4c01](https://github.com/seuros/active_project/commit/f1b4c01ff067cc756e7605d1413e23ee023fd123))
* Initial gem setup, README updates, and planning for integrations (Jira, Trello, GitHub, vibes). Also, considering npm, Deno.js, and Crystal because why not? ([d4b90aa](https://github.com/seuros/active_project/commit/d4b90aa498e3e3f09bd936daad94a85888fdf646))


### Bug Fixes

* release 0.1.0 ([7204218](https://github.com/seuros/active_project/commit/72042182fcbfe1064be4c11313175e7b6515a907))
* use version 2 of faraday ([c3ba298](https://github.com/seuros/active_project/commit/c3ba2980ee4e99c01e0bbcff134d2a9955bf3997))
