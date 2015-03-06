# Example from http://forum.nim-lang.org/t/959 thread in the forum
import strutils

type
    StringChannel = TChannel[string]

var
  channels : array[0..3, StringChannel]
  thr: array [0..3, TThread[ptr StringChannel]]

proc consumer(channel: ptr StringChannel) {.thread.} =
    echo channel[].recv()
    channel[].send("fighters")

proc main =
  for ix in 0..3: channels[ix].open()
  for ix in 0..3: createThread(thr[ix], consumer, addr(channels[ix]))
  for ix in 0..3: channels[ix].send("foo (" & intToStr(ix) & ")")
  joinThreads(thr)
  for ix in 0..3: echo channels[ix].recv()
  for ix in 0..3: channels[ix].close()

when isMainModule:
  main()
