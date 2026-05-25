#!/usr/bin/env python3
"""Simulate trigger testing using z-ai chat CLI.

For each query, we ask z-ai: "Given these available skills, which one would you use?"
If it picks stellar-frameworks for should-trigger queries, that's a PASS.
If it doesn't pick stellar-frameworks for should-not-trigger queries, that's a PASS.
"""
import json
import subprocess
import sys
import os
import time

SKILL_NAME = "stellar-frameworks"
SKILL_DESCRIPTION = """Core workflow — runs ALL tasks through a phase machine (SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER) without exception. Coding tasks: full phases with Traceability IDs and verification. Non-coding tasks (questions, explanations, recommendations): Minimal tier — all phases run internally, only IMPLEMENT produces output. Every task gets a Process Compliance Report. Covers building features, fixing bugs, refactoring, writing scripts, debugging, generating code, answering questions, explaining concepts, and providing recommendations. The phase machine always activates — complexity adapts, participation never skips."""

# Simulated available_skills snippet (realistic mix)
AVAILABLE_SKILLS = f"""
Available skills:
1. stellar-frameworks: {SKILL_DESCRIPTION}
2. pdf: Create, edit, and analyze PDF documents with professional formatting
3. docx: Create and edit Word documents with tracked changes and comments
4. xlsx: Create, read, edit Excel spreadsheets with charts and data analysis
5. charts: Create professional charts, diagrams, and data visualizations
6. image-generation: Generate images from text descriptions using AI
7. web-search: Search the web for real-time information
8. fullstack-dev: Fullstack web development with Next.js, TypeScript, Tailwind CSS
9. LLM: Chat completions and conversational AI capabilities
10. ASR: Speech-to-text transcription capabilities
"""

def test_trigger(query, should_trigger, timeout=60):
    """Test if the query triggers stellar-frameworks."""
    prompt = f"""You are GLM, an AI assistant. You have access to the following skills via the Skill tool:

{AVAILABLE_SKILLS}

A user sends this message:
"{query}"

Which skill, if any, would you invoke using the Skill tool? Consider whether the task is complex or multi-step enough to benefit from a skill. Simple one-step queries may not need any skill.

Respond with ONLY one of these exact formats:
- TRIGGER:stellar-frameworks (if you would invoke the stellar-frameworks skill)
- TRIGGER:<other-skill-name> (if you would invoke a different skill)
- NONE (if you would not invoke any skill)
- TRIGGER:fullstack-dev (if fullstack-dev is more appropriate)
"""

    try:
        result = subprocess.run(
            ["z-ai", "chat", "-p", prompt],
            capture_output=True,
            text=True,
            timeout=timeout,
            env={k: v for k, v in os.environ.items() if k != "GLMCODE"},
        )
        response = result.stdout.strip()
        
        # Parse response
        if f"TRIGGER:{SKILL_NAME}" in response:
            triggered = True
        elif "NONE" in response or "TRIGGER:" not in response:
            triggered = False
        else:
            # Triggered a different skill
            triggered = False
        
        return triggered, response[:200]
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"
    except Exception as e:
        return False, f"ERROR: {e}"

def main():
    eval_path = sys.argv[1] if len(sys.argv) > 1 else "eval_set.json"
    with open(eval_path) as f:
        eval_set = json.load(f)

    results = []
    for i, item in enumerate(eval_set):
        query = item["query"]
        should_trigger = item["should_trigger"]
        
        print(f"\n[{i+1}/{len(eval_set)}] Testing: {query[:60]}...", file=sys.stderr)
        
        triggered, detail = test_trigger(query, should_trigger)
        
        # Determine pass/fail
        if should_trigger:
            passed = triggered
        else:
            passed = not triggered
        
        result = {
            "query": query,
            "should_trigger": should_trigger,
            "triggered": triggered,
            "passed": passed,
            "detail": detail,
        }
        results.append(result)
        
        status = "PASS" if passed else "FAIL"
        expected = "should trigger" if should_trigger else "should NOT trigger"
        actual = "triggered" if triggered else "did NOT trigger"
        print(f"  [{status}] {expected}, {actual}", file=sys.stderr)
        print(f"  Detail: {detail}", file=sys.stderr)
    
    # Summary
    passed = sum(1 for r in results if r["passed"])
    total = len(results)
    
    pos_results = [r for r in results if r["should_trigger"]]
    neg_results = [r for r in results if not r["should_trigger"]]
    
    tp = sum(1 for r in pos_results if r["triggered"])
    fp = sum(1 for r in neg_results if r["triggered"])
    fn = sum(1 for r in pos_results if not r["triggered"])
    tn = sum(1 for r in neg_results if not r["triggered"])
    
    recall = tp / len(pos_results) if pos_results else 0
    precision = tp / (tp + fp) if (tp + fp) > 0 else 1.0
    specificity = tn / len(neg_results) if neg_results else 1.0
    accuracy = (tp + tn) / total if total else 0
    
    summary = {
        "overall": {"passed": passed, "total": total, "accuracy": f"{accuracy:.0%}"},
        "positive": {"should_trigger": len(pos_results), "triggered": tp, "missed": fn, "recall": f"{recall:.0%}"},
        "negative": {"should_not_trigger": len(neg_results), "correctly_rejected": tn, "false_positive": fp, "specificity": f"{specificity:.0%}"},
        "precision": f"{precision:.0%}",
        "results": results,
    }
    
    output_path = eval_path.replace(".json", "_results.json")
    with open(output_path, "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    
    print(f"\n{'='*60}", file=sys.stderr)
    print(f"TRIGGER TEST RESULTS", file=sys.stderr)
    print(f"{'='*60}", file=sys.stderr)
    print(f"Overall: {passed}/{total} ({accuracy:.0%})", file=sys.stderr)
    print(f"Should trigger: {tp}/{len(pos_results)} recalled ({recall:.0%})", file=sys.stderr)
    print(f"Should NOT trigger: {tn}/{len(neg_results)} correctly rejected ({specificity:.0%})", file=sys.stderr)
    print(f"Precision: {precision:.0%}", file=sys.stderr)
    print(f"False positives: {fp}", file=sys.stderr)
    print(f"False negatives: {fn}", file=sys.stderr)
    print(f"\nResults saved to: {output_path}", file=sys.stderr)
    
    return summary

if __name__ == "__main__":
    main()
