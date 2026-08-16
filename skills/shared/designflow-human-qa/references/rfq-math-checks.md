# RFQ cost and margin checks

Treat RFQ mathematics as a business-critical workflow. Do not decide correctness
from whether a cell changed. Calculate the expected result independently and
compare displayed and persisted values.

## Required sourcing-manager pass

Use a disposable licensed RFQ with simple, non-zero inputs. Record the before
state and enter known values for:

- factory or FOB cost;
- case pack and carton volume;
- freight or container cost;
- duty rate and any applicable tariff components;
- agent or other landed-cost additions shown by the grid;
- royalty rate;
- target margin for each tested selling basis.

Check the full chain shown by the application:

1. Freight per piece uses the displayed carton volume, case pack, and container cost.
2. Duty dollars use the displayed duty basis and rate.
3. Landed cost equals the applicable factory cost plus freight, duty, agent, and
   other visible additions for that shipping basis.
4. Licensed calculations include the entered royalty according to the app's
   stated price basis.
5. Selling price produces the entered target margin after all applicable costs.
6. Reverse editing a selling price produces the expected resulting margin.
7. Generic and licensed columns differ only where their named cost rules differ.
8. FOB, POE, warehouse, and mDDP results each use their correct cost base.
9. Changing royalty, duty, freight, or target margin recalculates every dependent
   value and does not alter unrelated fields.
10. Clearing an input follows the documented blank or zero behavior without
    leaving stale calculated values.
11. Undo, copy/paste, and fill-handle edits recalculate and persist correctly.
12. A hard reload returns the same saved inputs and calculated results.

Use at least these boundary cases when safe:

- zero royalty;
- a realistic non-zero royalty;
- zero and non-zero duty;
- a high but valid target margin;
- blank versus zero inputs;
- rounding near a half-cent or displayed percentage boundary.

Capture the exact inputs, independent arithmetic, displayed outputs, rounding
difference, record identifier, and reload result. Flag any unexplained difference,
even when it is small enough to look like rounding.
