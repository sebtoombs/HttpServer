# Express.js-like HTTP server library for NodeMCU

This library is a fork of the original library by T-vK: [NodeMCU-Express](https://github.com/T-vK/NodeMCU-Express). Improvements include;
- Execute routes/middlewares in correct  order
- Corrected path matching for routes vs middlewares

## About
This HTTP server library is very similar to the popular node.js module [express.js](https://expressjs.com/en/starter/hello-world.html).  
It's extremely intuitive and easy to use thus and I'm making the interface as similar as possible.  
The library is written in Lua.

## Get Started
Using this library is pretty simple.
1. Download [HttpServer.lua](HttpServer.lua) from this repository
2. Upload HttpServer.lua to your device
3. Require the library `require('HttpServer')` in your application code

## Example
For a full example go here: [example.lua](example.lua)

Here is the short version:
``` Lua
require('HttpServer')

local app = express.new()

-- Define a new middleware that prints the url of every request
app:use(function(req,res,next) 
    print(req.url)
    next()
end)

-- Define a new route that just returns an html site that says "HELLO WORLD!"
app:get('/helloworld',function(req,res)
    res:send('<html><head></head><body>HELLO WORLD!</body></html>')
end)

-- Serve the file `home.html` when visiting `/home`
app:use('/home',express.static('home.html'))

-- Serve all files that are in the folder `http` at url `/libs/...`
-- (To be more accurate I'm talking about all files starting with `http/`.)
app:use('/libs',express.static('http'))

app:listen()
```

## Serving files
Serving files is really easy and can be done with a single line of code.
Example of serving the file `home.html` at url `/home`:  
``` Lua
app:use('/home',express.static('home.html'))
```
To serve all files that are in a certain directory, let's say the directory is called `foo`, you can do:  
``` Lua
app:use('/example',express.static('foo'))
```
If you have a file called `foo/test.html` on your ESP8266 module and it's IP is 192.168.1.10, then you will be able to access it by visiting `http://192.168.1.10/example/text.html`.

## Routes
A route consists of a URL path and a function. Whenever someone visits the URL path, the function gets called. 

**Note**: regular expressions are currently not implemented.

For instance:  
``` Lua
-- Create a new route at `/led-on` an the connected function turns an LED on
app:get('/led-on',function(req,res)
    gpio.write(4, gpio.HIGH) -- set GPIO 2 to HIGH
    res:send('Led turned on!')
end)
```
We always start our path with `/`. If your ESP8266 has the IP 192.168.1.111 then you can open the route `/led-on` by typing `http://192.168.1.111/led-on` into your browser.

## Middlewares
A middleware consists of a function that gets called every time someone make an http request to our ESP8266 module.  
Using a middleware we can easily extend the functionality of our http server.  
For instance to add a cookie parser, a request logger, an authentication mechanism and muuuuuch more.  
Here is an example for a request logger:  
``` Lua
app:use(function(req,res,next) 
    print('New request!' .. ' Method: ' .. req.method .. ' URL: ' .. req.url)
    next()
end)
```

## Need help? Have a feature request? Found a bug?
Create an issue right here on github.