from ansible.plugins.callback import CallbackBase

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'clean_stdout'

    def v2_playbook_on_task_start(self, task, is_conditional):
        if task.action not in ('debug', 'setup', 'set_fact', 'meta'):
            name = task.get_name().replace("redis : ", "")
            self._display.display(f"\033[90m➜ {name}...\033[0m")

    def v2_runner_on_ok(self, result):
        if result._task.action == 'debug':
            msg = result._result.get('msg', '')
            if isinstance(msg, list):
                msg = '\n'.join(str(m) for m in msg)
            self._display.display(f"\n\033[97m{msg}\033[0m")

    def v2_runner_on_failed(self, result, ignore_errors=False):
        if not ignore_errors:
            msg = result._result.get('msg', result._result.get('stderr', 'Task failed'))
            self._display.display(f"\n\033[91m[ERROR] {msg}\033[0m")

    def v2_runner_on_unreachable(self, result):
        self._display.display(f"\n\033[91m[UNREACHABLE] {result._host.get_name()}\033[0m")

    def v2_playbook_on_stats(self, stats):
        self._display.display("\033[92m✔ Done.\033[0m\n")
