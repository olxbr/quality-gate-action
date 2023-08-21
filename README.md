# quality-gate-action
[![](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

This action collects repository and code information to validate if they are compliant with the **Quality Gate** pillars.

## Usage

```yml
- name: Quality Gate Action
  uses: olxbr/quality-gate-action@v0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```
## Inputs

#### `github_token`
The Github token is used to collect repository configuration data via the Github API and to add comments to Pull Requests. You can use PAT from github context `${{ secrets.GITHUB_TOKEN }}`, no need to generate a new one.

## Results

The result will be shown as a log of the action execution and as a comment in the Pull Request (coming soon).

![image](https://github.com/olxbr/quality-gate-action/assets/4138825/0eabc8a5-6676-40d2-894c-4616a1fa1a1b)

