extends Node

## Global Event Bus for routing player interactions.
## Adheres to Rule 30 (Autoloads for stateless event buses).

signal bed_sleep_requested()
signal conditioning_applied(type: String)

