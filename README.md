# V4
V4 - An example on how to (automatically) manage a Telnet connection using Expect Perl module.
V4 is an (automated) mobile system monitoring script which performs a lot of stuffs. Basically I wrote V4.pl to alleviate a system bug.
- A little inside of what the script actually doing:

Besides main switching (sub)systems (if we talk about a centralized architecture), one of the most important resources of a mobile system are BTSs (Base Transceiver Stations) which are spread all over the country and implement the radio coverage such that the users can access mobile services. In circuit switching mobile systems usually those BTSs are connected over 64Kb/s timeslots in E1 tributaries (2048Kb/s) through E1 multiplexers. The tributaries are carried over different media (e.g.: wires, fibers optic and (often) over radio relay systems). There are many reasons a tributary could fail (even for short periods of time) and then the associated BTS(s) are disconnected from the system. As a consequence in those areas (could be tens of Km2) the mobile services suffer. Usually when the tributary is up again BTS(s) are reconnected and re-operationalized. But some times, in some circumstances this don't happen automatically. Then manually commands needs to be issued from OMC (Operating & Maintenance Console) in order to transit those BTSs in operational state. This is where the V4 script is coming on the scene.
V4 periodically check the status of all BTSs in the system (not by pooling but actually checking active alarms) and try to re-operationalize those BTSs which are in INCORRECT WORKING STATE and have no CONNECTION BREAK alarm active.
- But enough with telecom issues and get back to software aspects:

V4 use Expect Perl module (https://metacpan.org/release/RGIERSIG/Expect-1.15/view/Expect.pod) to automatically manage a Telnet connection.
> Expect.pm is built to either spawn a process or take an existing filehandle and interact with it such that normally interactive tasks can be done without operator assistance.

In our case we spawn a telnet client process (line 143):
`$exp = Expect->new($telnet, @{$dxtS{$dxtNum}});`
Then we use $exp, the Expect object, for sending commands and receiving outcomes which are analyzed for appropriate actions. There are many specific app processing, but relevant in our case is to see how $exp object is used, how to address and use (some of) his public functions.:
```
$exp->command;
$exp->send(....);
$exp->expect(....);
$exp->clear_accum();
$exp->before;
$exp->match();
$exp->hard_close();
```
Alongside with docs on metacpan site this app should be useful to imagine how to automate otherwise manually interactive tasks. Also V4 can be seen as an example of (heavy) usage of regular expressions (a native feature of Perl language).
