import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';


List<TargetFocus> createTutorialTargets({
  required GlobalKey startButtonKey,
  required GlobalKey chartKey,
  required GlobalKey clearButtonKey,
  required GlobalKey importButtonKey,
  required GlobalKey rollAngleButtonKey,
  required GlobalKey pitchAngleButtonKey,
  required GlobalKey sampleButtonKey,
  required GlobalKey rollFftButtonKey,
  required GlobalKey pitchFftButtonKey,
  required GlobalKey vesselButtonKey,
  required GlobalKey loadingButtonKey,
  required void Function(String identify) onTargetScroll,
  required void Function(int index) onGoToStep,
  double radius = 8,
})
{
  List<TargetFocus> targets = [];
  const int totalSteps = 11;

  targets.add( //Start button
    TargetFocus(
      identify: "start_button",
      keyTarget: startButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            final target = targets.firstWhere((t) => t.identify == "start_button");
            final currentTargetIndex = targets.indexOf(target);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Press here to start collecting sensor data and display the roll and pitch curves.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (currentTargetIndex < targets.length) {
                      onTargetScroll(targets[currentTargetIndex].identify);
                    }
                    controller.next();
                  },
                  child: const Text("Next"),
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(0, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Chart
    TargetFocus(
      identify: "chart",
      keyTarget: chartKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "This chart shows roll angles (blue) and pitch angles (green) in real time. "
                      "You can navigate the graph using pinch-to-zoom gestures. Double-tap to reset the view.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => controller.previous(),
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () => controller.next(),
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(1, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
      enableOverlayTab: true,
    ),
  );

  targets.add( //clear button
    TargetFocus(
      identify: "clear_button",
      keyTarget: clearButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            final target = targets.firstWhere((t) => t.identify == "clear_button");
            final currentTargetIndex = targets.indexOf(target);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Press here to clear the curves.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (currentTargetIndex < targets.length) {
                          onTargetScroll(targets[currentTargetIndex].identify);
                        }
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(2, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //import button
    TargetFocus(
      identify: "import_button",
      keyTarget: importButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            final target = targets.firstWhere((t) => t.identify == "import_button");
            final currentTargetIndex = targets.indexOf(target);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Press here to import data from a CSV file. The file must contain the following columns in this exact order: time (s), roll (°), and pitch (°) in the first three columns.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (currentTargetIndex < targets.length) {
                          onTargetScroll(targets[currentTargetIndex].identify);
                        }
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(3, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Roll angle
    TargetFocus(
      identify: "roll_angle",
      keyTarget: rollAngleButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Displays the live roll angle; press the button to show or hide the roll curve.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(4, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Pitch angle
    TargetFocus(
      identify: "pitch_tile",
      keyTarget: pitchAngleButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Displays the live pitch angle; press the button to show or hide the pitch curve.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(5, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Time left
    TargetFocus(
      identify: "sample_tile",
      keyTarget: sampleButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Click to open a menu for selecting the number of samples, which determines the FFT measurement duration.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(6, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Roll period
    TargetFocus(
      identify: "roll_fft",
      keyTarget: rollFftButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Displays the actual rolling period value using spectral analysis. "
                      "You can also click on it to see a spectral graph.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(7, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Pitch period
    TargetFocus(
      identify: "pitch_fft",
      keyTarget: pitchFftButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Displays the actual pitch period value using spectral analysis."
                      "You can also click on it to see a spectral graph.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(8, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Vessel info
    TargetFocus(
      identify: "vessel_info",
      keyTarget: vesselButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Display the actuel vessel for data saving, you can choose a new one if you want",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.next();
                      },
                      child: const Text("Next"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(9, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  targets.add( //Loading info
    TargetFocus(
      identify: "loading_info",
      keyTarget: loadingButtonKey,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Display the actuel loading for data saving, you can choose a new one if you want",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        controller.previous();
                      },
                      child: const Text("Previous"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.skip();
                      },
                      child: const Text("End"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(10, totalSteps, onGoToStep),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: radius,
    ),
  );

  return targets;
}

/* A small "summary" is displayed below the text of each step
a row of numbered bullet points, with the current step's bullet point highlighted.
Tapping on a bullet point jumps directly to that step via [onGoToStep]
(which must call `tutorialCoachMark.goTo(index)` on the calling end).*/

Widget _buildStepIndicator(
    int currentIndex,
    int totalSteps,
    void Function(int index) onGoToStep,
    ) {
  return SizedBox(
    height: 32,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalSteps, (index) {
          final bool isActive = index == currentIndex;
          return GestureDetector(
            onTap: () => onGoToStep(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : Colors.white24,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              /*child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),*/
            ),
          );
        }),
      ),
    ),
  );
}