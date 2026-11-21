# Prior art and positioning

Research reviewed November 20, 2026. Public documentation cannot establish the
absence of competing implementations or disclose unreleased Apple work.

| Existing work | Documented overlap | Consequence |
| --- | --- | --- |
| [Siri calendar editing](https://support.apple.com/en-gb/148177) | Natural-language event changes, disambiguation, confirmation | Calendar actions are not novel |
| [Reclaim Preview Mode](https://help.reclaim.ai/en/articles/15280604-reclaim-2-0-faq) | Persistent staged changes and approval before applying | Preview/approve/apply is established |
| [FoundationModelsAgent](https://github.com/rudrankriyam/FoundationModelsAgent) | Approval and policy around Apple-model tool execution | A guarded agent wrapper is not a unique invention |
| [Apple Evaluations](https://developer.apple.com/documentation/Evaluations) | Model quality and regression evaluation | Evaluation infrastructure already exists |
| [ToolSandbox](https://machinelearning.apple.com/research/toolsandbox-stateful-conversational-llm-benchmark) | Stateful conversational tool-use evaluation | Failure scenarios follow an existing research direction |

Rehearsal is an independent engineering implementation, not a new research method
or an assertion that Apple lacks reliable action execution. Its value is a compact
Swift example with explicit guarantees, inspectable state, a native app, and
reproducible failure scenarios. No competitive performance claim is made.
