-- Express.js-like HTTP server Class
express = {
    new = function(tcpServe)
        if not tcpServer then
            tcpServer = net.createServer(net.TCP) 
        end
        
        local defaultPort = 80
        local supportedMethods = {'GET','POST','PUT','DELETE','HEAD'}
        local statusCodes = {
            [200] = 'OK',
            [201] = 'Created',
            [204] = 'No Content',
            [301] = 'Moved Permanently',
            [302] = 'Found',
            [303] = 'See Other',
            [304] = 'Not Modified',
            [400] = 'Bad Request',
            [401] = 'Unauthorized',
            [402] = 'Forbidden',
            [404] = 'Not Found',
            [409] = 'Conflict',
            [500] = 'Internal Server Error' 
        }
        local defaultHeaders = {
            ['Content-Type'] = 'text/html',
        }
        local defaultStatusCode = 200
        local defaultHttpVersion = 'HTTP/1.1'

        local expressInstance = {
            tcpServer = tcpServer;
            port = defaultPort;
            statusCodes = statusCodes;
            defaultStatusCode = defaultStatusCode;
            defaultHeaders = defaultHeaders;
            defaultHttpVersion = defaultHttpVersion; 
            middlewares = {};

            listen = function(this, port, ip)
                if port then
                    this.port = port
                end
                if ip then
                    this.ip = ip
                end

                this.tcpServer:listen(this.port, function(conn)
                    conn:on('receive',function(conn, rawRequest)

                        local req = {
                            app=this;
                            route={};
                            raw=rawRequest;
                            url=rawRequest:match("^%a+%s([^%s]+)%s");
                            method=rawRequest:match("^(%a+)%s[^%s]+%s");
                            httpVersion=rawRequest:match("^%a+%s[^%s]+%s([^\r]+)\r");
                        }
                        local res = {
                            app = this;
                            sendRaw = function(this,rawRes)
                                --print("Sending Response: "..rawRes)
                                conn:send(rawRes);
                                this._ended = true;
                            end;
                            _ended = false;
                            _headers = this.defaultHeaders;
                            statusCode = this.defaultStatusCode;
                            statusText = this.statusCodes[this.defaultStatusCode];
                            httpVersion = this.defaultHttpVersion;
                        }

                        function matchRoute(req, middleware)
                            local route = middleware.route
                            if req.url == route or route == "*" then return true end --Match get, post, all etc
                            --todo match regex on get post all etc
                            if middleware.method == '_USE' and string.sub(req.url,1,string.len(route)) == route then return true end --match use

                            return false
                        end

                        function testMiddleware(req, middleware)
                            if middleware.method == '_USE' and matchRoute(req, middleware) then
                                return true
                            end
                            if (middleware.method == req.method or middleware.method == '_ALL') and matchRoute(req, middleware) then
                                return true
                            end
                            return false
                        end
                        
                        -- Call middleware callbacks 
                        local middlewareToRun = {} -- all middlewares that need to be called
                        for i = 1, #this.middlewares do
                            local middleware = this.middlewares[i]
                            local callback = middleware.callback

                            if testMiddleware(req, middleware) then
                                --middlewareCallbacks[#middlewareCallbacks+1] = callback
                                table.insert(middlewareToRun, {["callback"]=callback, ["route"]=middleware.route})
                            end
                        end
                        local i = 1
                        function _next()
                            if(res._ended) then return end;
                            if i > #middlewareToRun then
                                return
                            end
                            local middlewareCallback = middlewareToRun[i].callback
                            req.route = middlewareToRun[i].route --I'm not totally sure about this
                            i = i+1
                            middlewareCallback(req,res,_next)
                        end
                        _next() -- call first middleware

                        
                    end)
                end)
            end;

            --internal function for adding all middlewares (use, get, post ec)
            _addMiddleware = function(this, method, route, callback)
                print('Adding middleware: '..method.." - "..route)
                table.insert(this.middlewares, {["callback"]=callback, ["route"]=route, ["method"]=method})
            end;
            
            use = function(this, route, callback) -- to add a middleware
                if callback == nil then
                    callback = route
                    route = '*'
                end;
                this:_addMiddleware('_USE', route, callback)
            end;
            all = function(this, route, callback) --to register routes on all HTTP methods
                this:_addMiddleware('_ALL', route, callback)
            end;
        }

        -- Dynamically generate class methods for every supported HTTP verb/method (get, post etc)
        for i = 1, #supportedMethods do
            local method = supportedMethods[i]
            expressInstance[method:lower()] = function(this, route, callback)
                expressInstance:_addMiddleware(method,route,callback) 
            end
        end;
        
        ------------------------------------------------------
        --------------- BUILT-IN MIDDLEWARES -----------------
        ------------------------------------------------------

       
        -- Response generator
        expressInstance:use(function(req,res,next)
            res.setHeader = function(this, key, value)
                if value == nil then
                    value= ''
                end
                this._headers[key] = value
                return this
            end
            res.removeHeader = function(this, key)
                this._headers[key] = nil
                return this
            end
            res.status = function(this, code)
                this.statusCode = code
                if this.app.statusCodes[code] then
                    this.statusText = this.app.statusCodes[code]
                else
                    this.statusText = this.app.statusCodes[200]
                end
                return this
            end
            -- Dedicated function for json body
            res.json = function(this,table)
                this:send(this, table)
                return this
            end
            res.send = function(this, body)
                
                if this._headers['Content-Length'] == nil then
                    this:setHeader('Content-Length', string.len(body))
                end


                local rawResponse = this.httpVersion .. ' ' .. this.statusCode .. ' ' .. this.statusText .. '\r\n'

                for key, value in pairs(this._headers) do
                    rawResponse = rawResponse .. key .. ': ' .. value .. '\r\n'
                end

                if body ~= nil and body:len() > 0 then
                    rawResponse = rawResponse .. '\r\n' .. body
                end

                this:sendRaw(rawResponse)

                this._headers = defaultHeaders --reset the _headers table after sending the response

                return this
            end
            res.endResponse = function(this)
                this:send()
                return this
            end
            next()
        end)
        
        return expressInstance
    end;

    -- Returns middleware to server static files 
    static = function(basePath)


        local stripTrailingSlash = function(str)
            if(string.sub(str, string.len(str), -1) == '/') then
                str = string.sub(str, 1, -2)
            end

            return str
        end
        local stripLeadingSlash = function(str)
            if(string.sub(str, 1,1) == '/') then
                str = string.sub(str, 2, -1)
            end
            return str
        end

        --[[if string.sub(basePath,1,1) == '/' then
            basePath = string.sub(basePath,2) -- remove leading '/'
        end]]

        basePath = stripLeadingSlash(stripTrailingSlash(basePath))

        local middleware = function(req,res,next)
            if req.method ~= "GET" and req.method ~= "HEAD" then
                res:status(405)
                res:setHeader('Allow', 'GET, HEAD')
                res:setHeader('Content-Length', 0)
                res:endResponse()
                return
            end
            local fileToServePath = basePath
            --[[if not file.exists(basePath) then
                local urlLen = string.len(req.url)
                local baseLen = string.len(basePath)
                fileToServePath = basePath .. req.url--string.sub(req.url,-(urlLen-baseLen+2))
            end]]

            local currentRoute = stripLeadingSlash(stripTrailingSlash(req.route))
            if(string.sub(currentRoute, string.len(currentRoute)) == '*') then
                currentRoute = string.sub(currentRoute, 1, -2)
            end

            local currentRequest = stripLeadingSlash(stripTrailingSlash(req.url))

            --print("SEP: "..package.config:sub(1,1))
            --print("Base: "..basePath)
            --print("Current route: "..currentRoute)
            --print("Request: "..currentRequest)

            if(string.sub(currentRequest, 1, string.len(currentRoute)) == currentRoute) then
                currentRequest = string.sub(currentRequest, string.len(currentRoute)+1)
                currentRequest = stripLeadingSlash(currentRequest)
            end


            --Replace URL slashes with filesystem separator
            currentRequest = currentRequest:gsub("/", package.config:sub(1,1))

            --print("Req: "..currentRequest)

            --Join it together
            if currentRequest:len() > 0 then
                fileToServePath = fileToServePath .. package.config:sub(1,1) .. currentRequest
            end
        
            --print("Path: "..fileToServePath)

            -- Look for directory and server index.html if required
            local s = file.stat(fileToServePath)
            if(s.is_dir) then
                fileToServePath = fileToServePath .. package.config:sub(1,1) .. 'index.html'
            end

            print("Serving file: "..fileToServePath)

            if file.exists(fileToServePath) then
                local fileToServe = file.open(fileToServePath, 'r')
                if fileToServe then
                    res:send(fileToServe:read())
                    fileToServe:close()
                    fileToServe = nil
                end
            else
                print("File not found")
            end

            next()
        end
        
        return middleware
    end;
}