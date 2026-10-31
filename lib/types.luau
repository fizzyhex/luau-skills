--!strict
-- Shared shapes for the Claude Code hook JSON protocol.

--- Decoded hook stdin. Only the fields the hooks read are typed.
export type HookInput = {
	session_id: string,
	agent_id: string?,
	cwd: string?,
	hook_event_name: string?,
	tool_name: string?,
	tool_input: any,
}

export type PostToolUseSpecificOutput = {
	hookEventName: "PostToolUse",
	additionalContext: string,
}

export type PostToolUseOutput = {
	decision: "block"?,
	systemMessage: string?,
	hookSpecificOutput: PostToolUseSpecificOutput?,
}

export type StopDecisionResult = {
	decision: "block"?,
	reason: string?,
	resetStopAttempts: boolean?,
}

export type StopDecisionInput = {
	errorFiles: { string },
	lintAttempts: { [string]: number },
	maxLintAttempts: number,
	stopAttempts: number,
}

--- Anything serialisable to the hook's stdout.
export type HookOutput = { [string]: any }

return {}
