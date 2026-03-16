#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER_NAME="micro_ros_agent_esp32"
DEFAULT_ROS_DISTRO="jazzy"
BAUD_RATE="115200"

# Optional override from first argument: ./run_micro_ros_agent.sh /dev/ttyUSB1
DEVICE_OVERRIDE="${1:-}"

# Track cleanup execution to avoid running it twice from multiple traps.
CLEANED_UP=0
AGENT_PID=0

choose_device() {
  local dev

  if [[ -n "${DEVICE_OVERRIDE}" ]]; then
    if [[ -e "${DEVICE_OVERRIDE}" ]]; then
      echo "${DEVICE_OVERRIDE}"
      return 0
    fi
    echo "ERROR: Device override '${DEVICE_OVERRIDE}' does not exist." >&2
    return 1
  fi

  for dev in /dev/ttyUSB*; do
    if [[ -e "${dev}" ]]; then
      echo "${dev}"
      return 0
    fi
  done

  for dev in /dev/ttyACM*; do
    if [[ -e "${dev}" ]]; then
      echo "${dev}"
      return 0
    fi
  done

  echo "ERROR: No serial device found. Looked for /dev/ttyUSB* then /dev/ttyACM*." >&2
  return 1
}

choose_docker_cmd() {
  # Request sudo once up front so signal-time cleanup can run non-interactively.
  if ! sudo -v; then
    echo "ERROR: sudo authentication failed." >&2
    return 1
  fi

  if sudo -n docker ps >/dev/null 2>&1; then
    echo "sudo docker"
    return 0
  fi

  echo "ERROR: Cannot access Docker with sudo." >&2
  return 1
}

cleanup() {
  if [[ "${CLEANED_UP}" -eq 1 ]]; then
    return 0
  fi
  CLEANED_UP=1

  if [[ -n "${DOCKER_CMD:-}" ]]; then
    sudo -n docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi

  echo "Cleanup complete: container '${CONTAINER_NAME}' is not running."
}

on_signal() {
  echo
  echo "Stop signal received. Shutting down container..."

  if [[ "${AGENT_PID}" -gt 0 ]] && kill -0 "${AGENT_PID}" 2>/dev/null; then
    kill -TERM "${AGENT_PID}" >/dev/null 2>&1 || true
  fi

  cleanup
  exit 0
}

main() {
  local ros_distro image device

  ros_distro="${ROS_DISTRO:-${DEFAULT_ROS_DISTRO}}"
  ros_distro="$(echo "${ros_distro}" | tr '[:upper:]' '[:lower:]')"
  image="microros/micro-ros-agent:${ros_distro}"

  DOCKER_CMD="$(choose_docker_cmd)"
  device="$(choose_device)"

  trap on_signal INT TERM
  trap cleanup EXIT

  echo "Detected ROS distro : ${ros_distro}"
  echo "Using Docker image  : ${image}"
  echo "Using serial device : ${device}"
  echo
  echo "Starting micro-ROS agent container..."

  # Ensure a stale container with the same name is removed before starting.
  ${DOCKER_CMD} rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

  ${DOCKER_CMD} run --rm \
    --name="${CONTAINER_NAME}" \
    --net=host \
    --device="${device}" \
    "${image}" \
    serial --dev "${device}" -b "${BAUD_RATE}" &

  AGENT_PID=$!

  # Wait for the agent and preserve its exit code without triggering set -e.
  set +e
  wait "${AGENT_PID}"
  local rc=$?
  set -e

  AGENT_PID=0
  return "${rc}"
}

main "$@"
