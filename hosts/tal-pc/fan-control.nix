{pkgs, ...}: {
  # Nuvoton fan tachometers on the ProArt X670E-CREATOR WIFI.
  boot.kernelModules = ["nct6775"];

  environment.systemPackages = [pkgs.lm_sensors];

  systemd.services.cpu-fan-curve = {
    description = "Quiet CPU-temperature curves for motherboard fans 1 and 2";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 5;
    };
    script = ''
      set -euo pipefail
      controller=
      cpu=
      for device in /sys/class/hwmon/hwmon*; do
        IFS= read -r name < "$device/name"
        case "$name" in
          nct6799) controller="$device" ;;
          k10temp) cpu="$device" ;;
        esac
      done
      [[ -n "$controller" && -n "$cpu" ]]
      IFS= read -r label < "$cpu/temp1_label"
      [[ "$label" == Tctl ]]

      # The hardware curves remain unchanged and take over on exit or failure.
      trap 'for fan in 1 2; do printf "5\n" > "$controller/pwm''${fan}_enable"; done' EXIT
      trap 'exit 0' TERM INT
      for fan in 1 2; do
        printf '0\n' > "$controller/pwm''${fan}_enable"
        printf '255\n' > "$controller/pwm$fan"
        printf '1\n' > "$controller/pwm''${fan}_enable"
      done

      previous=255
      while true; do
        IFS= read -r temperature < "$cpu/temp1_input"
        [[ "$temperature" =~ ^[0-9]+$ ]]
        (( temperature > 0 && temperature <= 115000 ))

        # Linear interpolation: 30C/20%, 55C/30%, 75C/50%, 95C/100%.
        if (( temperature <= 30000 )); then
          duty=51
        elif (( temperature <= 55000 )); then
          duty=$((51 + (temperature - 30000) * 26 / 25000))
        elif (( temperature <= 75000 )); then
          duty=$((77 + (temperature - 55000) * 51 / 20000))
        elif (( temperature < 95000 )); then
          duty=$((128 + (temperature - 75000) * 127 / 20000))
        else
          duty=255
        fi

        # Slow only the downward ramp to avoid audible speed oscillation.
        if (( duty < previous - 5 )); then
          duty=$((previous - 5))
        fi
        for fan in 1 2; do
          printf '%s\n' "$duty" > "$controller/pwm$fan"
        done
        previous=$duty
        sleep 1
      done
    '';
    # Also restore automatic control if the process is killed without a trap.
    postStop = ''
      for device in /sys/class/hwmon/hwmon*; do
        IFS= read -r name < "$device/name"
        if [ "$name" = nct6799 ]; then
          for fan in 1 2; do
            printf '5\n' > "$device/pwm''${fan}_enable"
          done
        fi
      done
    '';
  };
}
