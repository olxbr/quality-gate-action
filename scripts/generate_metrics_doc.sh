#!/bin/bash

export SUBMIT_METRICS_FILE_PATH="src/submit_metrics.sh"
export METRICS_DOC_FILE_PATH="docs/METRICS.md"

echo "╔══════════════════════════════════╗"
echo "║ GENERATING METRICS DOCUMENTATION ║"
echo "╚══════════════════════════════════╝"

echo "Metrics file: [$SUBMIT_METRICS_FILE_PATH]"
echo "Metrics doc file: [$METRICS_DOC_FILE_PATH]"

# Update the metrics documentation file with headers
echo -e "# Quality Gates Metrics
Definition of metrics sent to Datalake.

| Field | Type | Description |
| ----- | ---- |------------ |" >$METRICS_DOC_FILE_PATH

# Extract the metrics data from the metrics file
data=$(awk "/PAYLOAD=/,/\}'/" $SUBMIT_METRICS_FILE_PATH)

# Generate the metrics documentation
echo "Generating doc content..."
echo "$data" | while IFS= read -r line; do
    key=$(echo "$line" | grep -o '"[^"]*"' | sed 's/"//g' | head -n 1)
    type=$(echo "$line" | grep -o '## [^|]*' | sed 's/## //')
    desc=$(echo "$line" | grep -o '## [^|]* | .*' | sed 's/## [^|]* | //')

    # Skip empty lines
    [ -z "$key" ] && continue

    # Trim the type
    [ -n "$type" ] && type=\`$(echo "$type" | xargs)\`

    # Append the metrics to the documentation file
    echo "key: $key | type: $type | desc: $desc"
    echo -e "| **$key** | $type | $desc" >>$METRICS_DOC_FILE_PATH
done

# Add the footer to the metrics documentation file
{
    echo -e "---"
    echo -e "> Automatically generated from \`$SUBMIT_METRICS_FILE_PATH\` file, with \`scripts/generate_metrics_doc.sh\` script."
} >>$METRICS_DOC_FILE_PATH

echo "Metrics documentation generated successfully!"
