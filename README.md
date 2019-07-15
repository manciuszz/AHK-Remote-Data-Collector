# AHK | Remote Data Collector

It's a quick tool to collect and view data remotely by sending a POST request to a defined endpoint.

It works by using [**Server-Sent Events (SSE)**](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) API to start [**HTTP long-polling**](https://www.pubnub.com/blog/2014-12-01-http-long-polling/), therefore implementing your own client is as simple as...
```javascript
    let sourceEndpoint = 'http://localhost:8888/events';
    let evtSource = new EventSource(sourceEndpoint);
	evtSource.addEventListener("update", function(e) {
		myElement.innerHTML = e.data; // e.data contains your data string
	}, false);
```
*P.S You might be thinking - why LONG-POLLING? when we are talking about SSE here.. Well, I couldn't manage to keep-alive the established connection yet, so I chose the second best option - long polling.*

Collecting data is as simple as ...
```javascript
    let pushEndpoint = "http://localhost:8888/update";
    fetch(pushEndpoint, {  
        method: 'POST',  
        body: "YOUR PRECIOUS DATA" + JSON.stringify({"json": "is Allowed Too"})
    });
```

# Preview
![AHK|Remote Data Collector Preview](https://giant.gfycat.com/GrayGreenIrrawaddydolphin.gif)