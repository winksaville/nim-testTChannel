# Example from http://forum.nim-lang.org/t/959 thread in the forum
import strutils, times, parseopt2, threadpool, locks

when not defined(release):
  const DBG = true
else:
  const DBG = false

const
  numThreads = 2

var
  loops = 2

for kind, key, val in getopt():
  when DBG: echo "kind=" & $kind & " key=" & key & " val=" & val
  case kind:
  of cmdShortOption:
    case toLower(key):
    of "l": loops = parseInt(val)
    else: discard
  else: discard


type
  BiChannel[T] = object
    recvChnl: ptr TChannel[T]
    xmitChnl: ptr TChannel[T]

  IntegerBiChannel = BiChannel[int]


var
  thr: array [1..numThreads, TThread[BiChannel[int]]]

  chnl1: TChannel[int]
  chnl2: TChannel[int]
  pingChannels: BiChannel[int]
  pongChannels: BiChannel[int]

  gDone = false
  gDoneLock: TLock
  gDoneCond: TCond
  gPongCounter = 0
  gPingCounter = 0

proc ping(channel: BiChannel) {.thread.} =
  echo "ping start wait for first message"
  var v = channel.recvChnl[].recv()
  echo "ping running"
  while gPingCounter < loops:
    v += 1
    when DBG: echo "ping xmitChnl.send " & $v
    channel.xmitChnl[].send(v)
    when DBG: echo "ping recvChnl.recv"
    v = channel.recvChnl[].recv()
    when DBG: echo "ping v=" & $v
    gPingCounter += 1
  echo "ping done"
  

proc pong(channel: BiChannel) {.thread.} =
  echo "pong start"
  while gPongCounter < loops:
    when DBG: echo "pong recvChnl.recv"
    var v:int = channel.recvChnl[].recv()
    when DBG: echo "pong v=" & $v
    v += 1
    when DBG: echo "pong xmitChnl.send " & $v
    channel.xmitChnl[].send(v)
    gPongCounter += 1
  gDone = true;
  gDoneCond.signal()
  echo "pong done"

proc main =
  gDoneLock.initLock()
  gDoneCond.initCond()

  chnl1.open()
  chnl2.open()

  pingChannels.recvChnl = addr chnl1
  pingChannels.xmitChnl = addr chnl2

  pongChannels.recvChnl = addr chnl2
  pongChannels.xmitChnl = addr chnl1

  createThread(thr[1], ping, pingChannels)
  createThread(thr[2], pong, pongChannels)

  var
    startTime = epochTime()

  pingChannels.recvChnl[].send(0)

  gDoneLock.acquire()
  gDoneCond.wait(gDoneLock)

  var
    endTime = epochTime()
    messageCount = gPingCounter + gPongCounter
    time = (((endTime - startTime) / float(messageCount))) * 1_000_000

  # On my Ubuntu desktop 8.5us/msg
  echo "t5 done: time=" & time.formatFloat(ffDecimal, 4) & "us/msg"
  joinThreads(thr)

  chnl1.close()
  chnl2.close()
  echo "done"

when isMainModule:
  main()
