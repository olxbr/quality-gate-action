# quality-gate-action
[![](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

This action collects repository and code information to validate if they are compliant with the **Quality Gate** pillars.

## Usage

```yml
- name: Quality Gate Action
  uses: olxbr/quality-gate-action@main
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```
## Inputs

#### `github_token`
The Github token is used to collect repository configuration data via the Github API and to add comments to Pull Requests.

## Results

The result will be shown as a log of the action execution and as a comment in the Pull Request (coming soon).

![image](https://github.com/olxbr/quality-gate-action/assets/4138825/c6285ead-63fb-4a7b-9a6e-69eb49d463f1)
