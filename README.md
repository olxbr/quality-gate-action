# quality-gate-action
[![](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

This action collects repository and code information to validate if they are compliant with the **Quality Gate** pillars.

## Usage

```yml
- name: Quality Gate Action
  uses: olxbr/quality-gate-action@v0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    sonar_token: ${{ secrets.SONAR_TOKEN }}
    sonar_check_timeout: ${{ vars.SONAR_CHECK_TIMEOUT }}
    unit_test_check_timeout: ${{ vars.UNIT_TEST_CHECK_TIMEOUT }}
    unit_test_init_wait_timeout: ${{ vars.UNIT_TEST_INIT_WAIT_TIMEOUT }}
    gates_to_skip: ${{ vars.GATES_TO_SKIP }}
    docs_url: "your_docs_url"
    gh_metrics_server_endpoint: ${{ secrets.GH_METRICS_SERVER_ENDPOINT }}
```
## Inputs

#### `github_token`
The Github token is used to collect repository configuration data via the Github API and to add comments to Pull Requests. You can use PAT from github context `${{ secrets.GITHUB_TOKEN }}`, no need to generate a new one.

#### `sonar_token`
The Sonar token is used to collect code quality data via the Sonar API. You can generate a new token in your Sonar account.

#### `gates_to_skip` (default: "")
Comma separated list of gates to skip. The available gates are: `code_review`, `coverage`, `owner_approval`, `static_analysis`, `unit_test`.

#### `docs_url` (default: "")
Documentation URL to use in the report.

#### `gh_metrics_server_endpoint`
The endpoint of GITHUB Exporter to receives events from workflow. Useful to collect strategic metrics from quality gates.

#### `sonar_check_timeout`, `unit_test_check_timeout`, `unit_test_init_wait_timeout` (default: 60)
Sonar check timeout in minutes. If the timeout is reached, the action will not fail, but the result will be shown as a warning. The same applies to unit test check timeout.

## Results

The result will be shown as a log of the action execution, as a summary in action tab and as a comment in the Pull Request.

![image](https://github.com/olxbr/quality-gate-action/assets/4138825/32b030b9-a8ba-41f4-96da-df7e5a031bdc)

![image](https://github.com/olxbr/quality-gate-action/assets/4138825/67810ffd-14df-48ae-883e-fbf403c28b19)
