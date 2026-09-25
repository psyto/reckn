# Tokyo sponsor cards — ENS and Uniswap

**Pre-event conversation preparation only.** These are questions and measured observations for
in-person conversations. They are not outreach messages and do not claim event work exists.

## ENS — Identity for Apps, Agents & Beyond

### Opening, in plain English

> “I am exploring a record that an agent cannot write for itself. The right to write one record
> is a capability that settlement grants and then revokes. I am using ENSv2 as the permission
> layer, not as an identity lookup.”

### One observation to offer

> “The deployed Sepolia beta has a different ABI from `main`: both `initialize` and `setText`
> differ. I also found that `grantSetterRoles` takes setter calldata, not a name.”

Only offer this if the conversation is technical. It is a report from measured interaction with
the beta, not a criticism.

### Questions

1. “Is per-record granularity through setter calldata an intended use to build on?”
2. “We measured that root roles can be renounced. Is that intended to remain a stable property?”
3. “Is the Sepolia beta ABI converging with `main`? Which surface should an app that must work in a month target?”
4. “For agents as namespaces, what would you want a useful record surface to look like?”

### Do not say

- “ERC-8004 has a hole.” The specification already discloses Sybil limitations.
- “ENS fixes identity.” It provides a capability surface here; it does not identify a person.
- “We have users.” Reckn does not have external users.

## Uniswap — How to Navigate the Uniswap Stack

### Opening, in plain English

> “We reran a real Uniswap v3 `SwapRouter02.exactInputSingle` swap inside a zk guest: about
> thirteen million cycles. We use v3 for the work being checked, and a v4 `beforeSwap` hook as
> the place where an earned record is spent.”

### The useful technical finding

> “We did not put the Universal Router on the proving path. Permit2 uses `ecrecover`, and our
> guest has not established equivalence for that precompile. We would rather state that limit
> than claim soundness we have not measured.”

### Questions

1. “Is the hook flag encoding stable enough that mining an address per code change is the expected workflow?”
2. “For ERC-7751 wrapped errors, is the outer `bytes4` intended to identify the hook function rather than the inner error?”
3. “Is there a router path that avoids Permit2’s signature step and is useful for a proving path?”
4. “Where do you think hooks should not be used?”

### Do not say

- “We proved a v4 swap.” The rerun workload is a v3 `SwapRouter02` swap.
- “The gate protects liquidity.” The gate applies to trading, not liquidity provision.
- Any criticism of Uniswap’s pricing, safety, or design. It is both the workload and the venue.

## Conversation rule

Ask one question, listen, and take a note. Do not turn the interaction into a pitch unless the
other person asks what is being built.

