## Description

This is a sandbox used to investigate how Thin and EventMachine can be used to increase the throughput for a typical rails app.

## Methodology:
 - ab for quick benchmarks. Follow these instructions if you're on Lion to avoid a couple hours of WTF: http://forrst.com/posts/Fixing_ApacheBench_bug_on_Mac_OS_X_Lion-wku
 - created a vanilla 3.1 rails app with a single scaffolded model so I could focus on adding a simple delay to the controller
 - followed much of the setup of https://github.com/igrigorik/async-rails especially the part about using the Rack::FiberPool plugin
 - initially tried adding a "sleep 5" to the controller to simulate a long call, but this wasn't working well, so I created a standalone server that responds "okay" after 5 seconds, based on http://www.igvita.com/2008/05/27/ruby-eventmachine-the-speed-demon/  (see results section)
 - controller method makes one call to fetch a page from the slow http server, then renders the text of that page as its response (verified this with curl)


## Results:
 - load testing script/slow_http_server.rb which runs on port 3001, just to make sure it's working as desired. It has a 5 second sleep for every response, so 10 responses would take 50 seconds if they were in serial, and 5 if they are in parallel:
    bash$ ab -n 10 -c 10 http://127.0.0.1:3001/
    ...
    Time taken for tests: 5.003 seconds
 
 - load testing the vanilla rails app that makes an em-http request to the slow http server for every request:
    bash$ ab -n 10 -c 10 http://127.0.0.1:3000/comments
    ...
    Time taken for tests: 10.026 seconds
    mean wait time: 7.522s
    median wait time: 10.025s

 - I can actually replace the EM::HttpRequest call with an EM::Synchrony.sleep(5) call and get the same results, so this will useful for future testing 
    bash$ ab -n 100 -c 100 http://127.0.0.1:3000/comments
    Time taken for tests:  10.250 seconds
    Non-2xx responses (failures): 15
   (same number of failures even when I increased the fiber pool size to 200)

## Analysis:
 - the FiberPool plugin is definitely working, as it gave us between a 5x and a 50x increase in throughput!
 - using FiberPool can be a huge gain for us where we can make use of em-httprequest (it hooks into httparty, so this is in many places)
 - this rack plugin method isn't as efficient as it can be (2x as slow), but allows us to stay with the rails framework (as opposed to going to something like goliath)
 - this won't increase the speed of the app, but if >50% of a request is being spent in IO, then this will greatly improve the throughput

## Next Steps:
 - what is the potential impact of making this change, and how does it stack up against the other possible next steps (below)
 - speed up responses so we can increase the throughput
    - better algorithms
    - bulk calls to APIs
    - more caching of API calls
    - parallelize anything that can be parallelized (either through threads, Fibers, or EM blocks)
 - reduce memory usage so we can scale to more instances
    - make sure we free objects we don't need
    - memory profiling should point to where the big wins are here

## Notes:
 - this should be required reading: http://merbist.com/2011/02/22/concurrency-in-ruby-explained/ -- seriously, read this if you've ever thought, or heard someone say "Rails can't scale"!
 - launching thin via "thin start", and need to stop/start every time I make a code change
 - I have all the code for this on my local computer and can share it if it's useful
 - We'll also benefit from EM-aware activerecord connectors, but these won't always be trivial to hook up (or test)
 - We'll have to play around with the number of clients we want in the queue for each thin server, as too many concurrent requests will just steal time from each other. I'd suggest having either apache or haproxy routing dynamic requests to the thin servers, with static assets being served elsewhere
 - This initially was to report discouraging results, but as I typed up the methodology, I got inspired to try one more thing. Being methodical is a good thing :D
