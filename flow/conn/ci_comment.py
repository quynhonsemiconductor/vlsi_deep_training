"""The PR comment of the CI job "Connectivity", from build/conn/report.md.

    python3 flow/conn/ci_comment.py REPORT TITLE [RUN_URL] > comment.md

GitHub refuses a comment over 65536 characters, and a comment cut at a byte count
can end inside the Mermaid block, which then renders as boxes without wires. So the
comment is never cut: when the whole report does not fit, the per-block tables (the
folded part between the conn-tables markers that connectivity.py writes) are dropped,
and the comment points at the job summary, which keeps the full report. Verdicts and
diagrams always stay.
"""
import re
import sys

LIMIT = 60000          # under GitHub's 65536, with room for the title and the note


def main():
    report, title = sys.argv[1], sys.argv[2]
    run_url = sys.argv[3] if len(sys.argv) > 3 else ""
    text = open(report).read()
    body = f"{title}\n\n{text}"
    if len(body) > LIMIT:
        short = re.sub(r"<!-- conn-tables -->.*?<!-- /conn-tables -->",
                       "*Tables omitted: too long for a comment.*", text, flags=re.S)
        where = f"[the job summary]({run_url})" if run_url else "the job summary"
        body = (f"{title}\n\nPorts, pins and assigns of every block are in {where}; "
                f"this comment keeps the verdicts and the diagrams.\n\n{short}")
    cut = body.rfind("\n#### ", 0, LIMIT)
    if len(body) > LIMIT and cut > 0:    # many large blocks at once: drop whole blocks
        body = body[:cut] + f"\n\n*Further blocks omitted: see {run_url or 'the job summary'}.*\n"
    sys.stdout.write(body)


if __name__ == "__main__":
    main()
