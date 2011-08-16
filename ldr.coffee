# currently no cmdline client, run with "coffee coffeeloader.coffee"

# listen on every available IP
ip = "0.0.0.0"

# listen port
port = 8080

coffee = require('coffee-script')
http = require('http')
fs = require('fs')
url = require('url')
log4js = require('log4js')

# Bitmask-style object to specify the source process steps
processMode =
	crypt: 1
	minify: 2
	obfuscate: 4
	pack: 8

# sample profile
# TODO needs to put into a folder
profile =
	name: "debug"
	access: "public"
	mode: processMode.obfuscate | processMode.minify

# basic logger if no custom is set

log = log4js.getLogger("coffeeloader MAIN")
# create webserver and register our ldrRequest handle
instance = http.createServer (request, response)  ->
	try
			req = new coffeeloader(request, response)
	catch err
			log.error err

instance.listen port, ip
log.info "Server running at http://#{ip}:#{port}/"

class coffeeloader
	@log = null
	@request = null
	@response = null

	constructor:	(@request, @response) ->
		@log = log4js.getLogger("coffeeloader")
		@log.debug "coffeeloader created, Url #{@request.url}"
		@openFile()
		
	openFile: () ->
		# dismantle the url into folder/file parts, only char/number/underscore are returned	
		parts = (folder.match(/\w+/)[0] for folder in url.parse(@request.url).pathname.split("/") when folder.length > 0)
		# right now we limit to 2 parts
		return @abort(new error(null, 403)) if parts.length != 2
		folder = parts.shift()
		file = parts.shift()

		mode = processMode.obfuscate | processMode.minify
	
		s = new script(folder, file)
		s.open mode, (err, sourcecode) =>
			return @abort(err) if err
			@response.writeHead(200, {'Content-Type': 'text/javascript'})
			@response.end(sourcecode)
			log.info "delivered #{@request.url} from #{s.folder}/#{s.requestFile}"
	abort: (err) ->
		@response.writeHead(err.code, {'Content-Type': 'text/html'})
		if (err.msg?) then @response.end("" + err.msg) else @response.end()
		log.error "#{err.code} #{err.msg}, #{@request.url}"
		return -1

class script
	# filename when ending is found (js/coffee)
	@requestFile= null
	# one folder or multiple folder as path (relative)
	@folder = null
	# "js" or "coffee"
	@type = null

	constructor: (@folder, @file) ->
		@log = log4js.getLogger('scriptFile')

	# looks for file with ending .js or .coffee
	# callback is of (err, string)
	open: (@mode, callback) ->
		@log.debug "attempting to open folder #{@folder}"
		fs.readdir @folder, (err, files) =>
			return callback(new error(err, 404), null) if err

			@log.debug "successfully opened folder, contains #{files}"
			@log.debug "looking for #{@file}.js|.coffee"
			if files.indexOf(@requestFile = @file + ".js") >= 0
				@log.debug ("found .js file!")
				@type = "js"
			else if files.indexOf(@requestFile = @file + ".coffee") >= 0
				@log.debug ("found .coffee file!")
				@type = "coffee"
			else
				callback(new error("file not found", 404), null)
				return
			# open the file
			fs.readFile @folder + "/" + @requestFile , "utf8", (err, data) =>
				return callback(new error(err, 404), null) if err
				@log.debug "file open successfull, parsing file"
				@parse(data, callback)

	# returns a the encoded/crypted source as string	
	# callback is of (err, string)
	parse: (src, callback) ->
		@processor = new scriptProcessorJS() if @type == "js"
		@processor = new scriptProcessorCoffee() if @type == "coffee"
		
		# we start with plaintext
		current = src
		if @mode & processMode.minify
			current = @processor.minify(current)
		if @mode & processMode.obfuscate
			current = @processor.obfuscate(current)
		if @mode & processMode.pack
			current = @processor.pack(current)

		callback(null, current)

# abstract class, do not create an instance 
class scriptProcessor
	@log = log4js.getLogger('scriptProcessorJS')
	obfuscate: (code) =>
		return code
	minify: (code) ->
		return code
	pack: (code) ->
		return code
	crypt: (code) ->
		return code

class scriptProcessorJS extends scriptProcessor
	@log = log4js.getLogger('scriptProcessorJS')
	obfuscate: (code) =>
		log.debug("obfuscating JS code")
		return code

class scriptProcessorCoffee extends scriptProcessor
	@log = log4js.getLogger('scriptProcessorCoffee')
	obfuscate: (code) =>
		log.debug("compiling coffee code")
		return coffee.compile(code)


class error
	constructor: (@msg, @code) ->
		# ntn
