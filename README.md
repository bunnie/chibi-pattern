chibi-pattern
=============

Pattern generator code for chibitronics circuit stickers

Four patterns are defined: 
* blink
* fade
* heartbeat
* twinkle

All four patterns are dynamically dispatchable based upon
a voltage read in by the ADC. The sticker only appears to
have a static behavior because the voltage is set by a 
resistor divider soldered onto the sticker. However, it is
possible to modify the voltage divider and/or drive the
divider directly to modify the pattern behavior dynamically.

Pattern behavior is implemented using PWM state switching. 
All patterns, including simple on-off patterns, are actually
done using a PWM value, and a linear interpolation between
the requested states to create a "soft" feel to the lighting
transitions. 

Note that due to a quirk in the PWM circuit behavior, "full-off"
has to be special-cased. This is particularly noticeable for
the blink case, where the sticker spends a bit of time in the
full-off state. This is because the max value of the PWM output
isn't full-on; there is always at least a ~0.5% on-state, so 
the sticker looks to be very dim, rather than off. As a hack,
for blink we detect when we request PWM to be 0, and in that
case we hard disconnect the PWM. On the transition back to
on, we re-connect PWM.

No interrupts are used in this code. 

All delays are coded using busy-wait loops.
