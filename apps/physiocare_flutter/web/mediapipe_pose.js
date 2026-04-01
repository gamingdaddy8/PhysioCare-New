let pose = null;
let videoElement = null;
let stream = null;

function waitForVideo(videoId) {
  return new Promise((resolve) => {
    const check = () => {
      const el = document.getElementById(videoId);
      if (el) return resolve(el);
      requestAnimationFrame(check);
    };
    check();
  });
}

function waitForFlutterCallback() {
  return new Promise((resolve) => {
    const check = () => {
      if (window.onPoseLandmarks) return resolve();
      requestAnimationFrame(check);
    };
    check();
  });
}

window.startMediapipePose = async function (videoId) {
  console.log("startMediapipePose called");

  videoElement = await waitForVideo(videoId);
  await waitForFlutterCallback();

  stream = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480 },
    audio: false,
  });

  videoElement.srcObject = stream;
  await videoElement.play();

  try {
    pose = new Pose({
      locateFile: (file) => `mediapipe/pose/${file}`,
    });

    pose.setOptions({
      modelComplexity: 1,
      smoothLandmarks: true,
      enableSegmentation: false,
      selfieMode: true,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });

    pose.onResults((results) => {
      if (results.poseLandmarks && window.onPoseLandmarks) {
        window.onPoseLandmarks(results.poseLandmarks);
      }
    });
  } catch (e) {
    console.error("Failed to initialize MediaPipe Pose:", e);
    return;
  }

  async function frameLoop() {
    if (!pose || !videoElement) return;
    try {
      await pose.send({ image: videoElement });
    } catch (e) {
      console.error("Error sending image to MediaPipe:", e);
      return;
    }
    requestAnimationFrame(frameLoop);
  }

  frameLoop();
};

window.stopMediapipePose = function () {
  if (pose) {
    pose.close();
    pose = null;
  }

  if (stream) {
    stream.getTracks().forEach((t) => t.stop());
    stream = null;
  }

  if (videoElement) {
    videoElement.pause();
    videoElement.srcObject = null;
    videoElement = null;
  }
};