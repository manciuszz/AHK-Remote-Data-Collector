#NoEnv
#Persistent
#KeyHistory 0
#SingleInstance, force
SetBatchLines, -1

#include <AHKhttp>
#include <MimeTypes>

@paths := {}

server := new HttpServer()
server.LoadMimes(getMimeTypes())
server.SetPaths(@paths)
server.Serve(8888)
; Run % "http://localhost:8888"

@paths["/"] := Func("mainPage")
mainPage(ByRef req, ByRef res) {
    html := mountHTML()
	res.headers["Content-Type"] := "text/html"
    res.SetBodyText(html)
    res.status := 200
}

@paths["404"] := Func("notFound")
notFound(ByRef req, ByRef res) {
    res.SetBodyText("404 - Page not found!")
	res.status := 404
}

@paths["/asset/*"] := Func("asset")
asset(ByRef req, ByRef res, ByRef server) {
    server.ServeFile(res, Utilities.RelativePath(req.queries.path))
	if (!res.headers["Content-Type"])
		return notFound(req, res)
	res.headers["Cache-Control"] := "max-age=3600"
    res.status := 200
}

@paths["/update"] := Func("update")
update(ByRef req, ByRef res) {
	DataStream.storeData(req.body).build()
	res.headers["Access-Control-Allow-Origin"] := "*"
	res.headers["Content-Type"] := "text/event-stream"
	res.SetBodyText("OK")
	res.status := 200
	PersistenceController.notifyHandlers()
}

@paths["/events"] := Func("events")
events(ByRef req, ByRef res) {
	res.headers["Connection"] := "keep-alive"
		
	data := DataStream.get()
	if (!data)
		return
		
	res.headers["Access-Control-Allow-Origin"] := "*"
	res.headers["Content-Type"] := "text/event-stream"
	res.headers["Cache-Control"] := "no-cache"
	
	res.SetBodyText(DataStream.clear().retry(1).event("update").set(Utilities.Cache("data", DataStream.getLog(), true, true), false).build())
	res.status := (DataStream.includes("Close") ? 204 : 200)
	DataStream.clear()
}

@paths["/eventsTerminate"] := Func("eventsTerminate")
eventsTerminate(ByRef req, ByRef res) {
	DataStream.set("Close").build()
	res.SetBodyText("Success")
	res.status := 200
}

@paths["/eventsUpdateTest"] := Func("eventsUpdate")
eventsUpdate(ByRef req, ByRef res) {
	DataStream.event("test").set("Updated!").build()
	res.SetBodyText("Success")
	res.status := 200
}

@paths["/eventsResumeTest"] := Func("eventsResume")
eventsResume(ByRef req, ByRef res) {
	DataStream.event("test").set("Resumed!").build()
	res.SetBodyText("Success")
	res.status := 200
}

class DataStream {
	static _ := DataStream = new DataStream()
	
	__New() {
      	this.clearLog()
		this.clear()
	}
	
	clear() {			
		this.data := ""
		this.rawData := ""
		return this
	}
	
	clearLog() {
		this.dataLog := ""
		return this
	}

	get() {
		return this.data
	}
	
	getRaw() {
		return this.rawData
	}
	
	getLog() {
		return this.dataLog
	}
	
	setLog(newData) {
		this.dataLog .= "<p>" . newData . "</p>"
	}
	
	storeData(newData) {
		this.rawData := newData
		this.setLog(newData)
		return this
	}
	
	set(newData, shouldStore := true) {		
		if (shouldStore)
			this.storeData(newData)
		this.data .= this.streamCommand("data", newData)
		return this
	}
	
	retry(timeMS := 1) {
		this.data .= this.streamCommand("retry", timeMS)
		return this
	}
	
	event(id) {
		this.data .= this.streamCommand("event", id)
		return this
	}
	
	includes(str) {
		return InStr(this.data, str)
	}
	
	streamCommand(key, value) {
		return key . ": " . value . "`n"
	}
	
	build() {
		this.data .= "`n"
		return this.get()
	}
}

class Utilities {
	FileRead(path) {
		FileRead, output, % this.RelativePath(path)
		return output
	}

	RelativePath(path) {
		return A_ScriptDir . path
	}
	
	Cache(key, value, shouldCache := false, forceOverwrite := false) { ; Enables RAM type caching strategy.
		static @cache := {}
		
		if (IsObject(value) && (!shouldCache || !@cache[key]))
			value := value.Call()
				
		if (!shouldCache)
			return value
		
		if (!@cache[key] || forceOverwrite)
			@cache[key] := value

		return @cache[key]
	}
	
	; CleanMemory(PID = ""){
		; PID := ((PID = "") ? DllCall("GetCurrentProcessId") : PID)
		; hWnd := DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", PID)
		; DllCall("SetProcessWorkingSetSize", "UInt", hWnd, "Int", -1, "Int", -1)
		; DllCall("CloseHandle", "Int", hWnd)
	; }
}


mountHTML(htmlEndpoint := "/static/index.html", pos := 1) {	
	elementsToBind := {}
	elementsToBind.title := "AHK | Data Collector"
	elementsToBind.msg := Utilities.Cache("data", "<p>No data collected, yet.</p>", true, true)
	DataStream.clearLog()
	
	HTML := Utilities.Cache(htmlEndpoint, ObjBindMethod(Utilities, "FileRead", htmlEndpoint))
	while ( pos := RegExMatch(HTML, "O){{(.*)}}", foundMatch, pos + StrLen(foundMatch.1)) ) {
		bindings := StrSplit(foundMatch.1, "+")
				
		content := ""
		Loop % bindings.MaxIndex() {
			binding := Trim(bindings[ A_Index ])
			content .= elementsToBind[ binding ]
		}
		HTML := StrReplace(HTML, "{{" . foundMatch.1 . "}}", content)
	}
    	
    return HTML
}

; Hotkeys
#If WinActive("ahk_exe notepad++.exe")
^R::Reload