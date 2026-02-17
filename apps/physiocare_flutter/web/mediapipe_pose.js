let camera = null;
let pose = null;

// Flutter will call this and pass the video element id
window.startMediapipePose = async function (videoId) {
  if (pose) return;

  const videoElement = document.getElementById(videoId);

  if (!videoElement) {
    console.error("Video element not found:", videoId);
    return;
  }

  pose = new Pose.Pose({
    locateFile: (file) =>
      `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`,
  });

  pose.setOptions({
    modelComplexity: 1,
    smoothLandmarks: true,
    enableSegmentation: false,
    smoothSegmentation: false,
    minDetectionConfidence: 0.5,
    minTrackingConfidence: 0.5,
  });

  pose.onResults((results) => {
    if (results.poseLandmarks) {
      if (window.onPoseLandmarks) {
        window.onPoseLandmarks(results.poseLandmarks);
      }
    }
  });

  camera = new Camera.Camera(videoElement, {
    onFrame: async () => {
      await pose.send({ image: videoElement });
    },
    width: 640,
    height: 480,
  });

  camera.start();
};

window.stopMediapipePose = function () {
  if (camera) {
    camera.stop();
    camera = null;
  }
  if (pose) {
    pose.close();
    pose = null;
  }
};