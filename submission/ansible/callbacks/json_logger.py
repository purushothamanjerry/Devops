# pyrefly: ignore [missing-import]
from ansible.plugins.callback import CallbackBase
import json
import datetime
import os

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'json_logger'

    def __init__(self, display=None):
        super(CallbackModule, self).__init__(display)
        # Assuming the playbook is in ansible/playbooks, __file__ is ansible/callbacks/json_logger.py
        # We want to log to logs/operations.log in the workspace root
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.log_file = os.path.join(base_dir, 'logs', 'operations.jsonl')
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)

    def log_event(self, node, action, outcome, result=None):
        entry = {
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "node": node,
            "action": action,
            "outcome": outcome,
            "details": result.get('msg', '') if isinstance(result, dict) else str(result)
        }
        try:
            with open(self.log_file, "a") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass

    def v2_runner_on_ok(self, result):
        self.log_event(result._host.get_name(), result._task.get_name(), "OK", result._result)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self.log_event(result._host.get_name(), result._task.get_name(), "FAILED", result._result)

    def v2_runner_on_unreachable(self, result):
        self.log_event(result._host.get_name(), result._task.get_name(), "UNREACHABLE", result._result)

    def v2_runner_on_skipped(self, result):
        self.log_event(result._host.get_name(), result._task.get_name(), "SKIPPED", result._result)
