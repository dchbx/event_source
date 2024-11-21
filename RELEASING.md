# Release

This file describes the process for publishing a new version of the gem as a GitHub release.

Releases are managed through the [GitHub Releases](https://github.com/dchbx/event_source/releases) page.

Release names follow the [Semantic Versioning](https://semver.org/) standard.

Follow the steps below to package and release a new version of the gem.

## Local Release Preparation
1. Checkout the main branch and pull the latest changes.
2. Create a branch name using the desired version number followed by the `-release` suffix, e.g., `1.0.0-release`.
3. Update the version number in the `lib/event_source/version.rb` file. Note the [correct format](https://guides.rubygems.org/specification-reference/#version); only digits and dots are allowed. Do not include a `v` prefix.
4. Update the `Gemfile.lock` file using the most appropriate command:
    - `bundle update --patch --conservative event_source` for a patch release.
    - `bundle update --minor --conservative event_source` for a minor release.
    - `bundle update --major --conservative event_source` for a major release.
    - See bundler documentation for detailed information on how these [commands](https://bundler.io/v2.5/man/bundle-update.1.html) behave.
5. Commit the changes with a message like `bump version to v1.0.0`.
6. Push the branch and raise a pull request against trunk. The pull request title should follow the format: `bump version to v1.0.0`. Be sure to label the pull request with the `version-bump` label.


## Publishing the Release
1. Once the pull request is approved and merged, checkout the main branch and pull the latest changes.
2. Create a new annotated tag with the version number, e.g., `git tag -a v1.0.0 -m "v1.0.0"`.
    - IMPORTANT: make sure the tag abides by the format `vX.Y.Z` where `X`, `Y`, and `Z` are integers. It is important that the tag name has a different format than the branch name to avoid confusion with Bundler.
3. Push the tag to the remote repository, e.g., `git push origin refs/tags/v1.0.0`.
4. GitHub Actions will automatically create a new release on the [GitHub Releases](https://github.com/dchbx/event_source/releases) page with release notes. Confirm that the release was successfully published there and that all intended commits are included in the release.

## Using a Tagged Release in Another Project
To use the new release in another project, update the project's `Gemfile` to reference the release's tag, e.g., `gem 'event_source', git: 'https://github.com/dchbx/event_source.git', tag: 'v1.0.0'`.