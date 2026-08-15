# PantryPal realtime event contract

Socket.IO events are household-scoped. Each payload includes `householdId`, `entityId`, `revision`, `actor`, and `occurredAt`. A client that observes a revision gap refetches authoritative REST state rather than attempting local reconciliation.

| Event | Entity | Purpose |
|---|---|---|
| `import.progress` | Import job | Stage and bounded progress changed |
| `import.ready` | Import job | Review draft is available |
| `import.failed` | Import job | Specific recoverable error is available |
| `household.activity.created` | Activity event | Shared action was attributed |
| `recipe.changed` | Recipe | Version or readiness changed |
| `cooking.changed` | Cooking instance | Plan, serving, trip, or archive state changed |
| `cook_assignment.requested` | Cook transfer | Target has a pending transfer |
| `cook_assignment.resolved` | Cook transfer | Transfer was accepted, declined, or cancelled |
| `trip.changed` | Shopping trip | Lifecycle/date/assignment changed |
| `shopping_item.changed` | Shopping item | Aggregate or shopping status changed |
| `pantry.recheck_required` | Shopping item | Later demand invalidated unquantified availability |
| `notification.created` | Notification | In-app notification was persisted |

`actor` is `{ accountId, displayName }`; it is a safe historical summary rather than a current profile lookup. Payloads never contain raw imported media, refresh credentials, complete account records, or unredacted source comments.
