local f = string.format



local function formatLine(lineNum, msg, ...)
	return f("line %d: %s", lineNum, f(msg, ...))
end

local function formatColumn(columnNum, msg, ...)
	return f("column %d: %s", columnNum, f(msg, ...))
end

local function formatArg(argNum, msg, ...)
	return f("arg %d: %s", argNum, f(msg, ...))
end

local function formatFuncName(funcName, msg, ...)
	return f("fn %s: %s", funcName, f(msg, ...))
end

local function errWithTrace(msg, trace, ...)
	return f("%s (%s)", f(msg, ...), table.concat(trace, " > "))
end



return {
	formatLine = formatLine,
	formatColumn = formatColumn,
	formatArg = formatArg,
	formatFuncName = formatFuncName,
	errWithTrace = errWithTrace,
}