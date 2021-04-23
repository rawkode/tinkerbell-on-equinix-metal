import * as pulumi from "@pulumi/pulumi";
import * as metal from "@pulumi/equinix-metal";

export = async () => {
  const config = new pulumi.Config("");

  const project = await metal.getProject({
    name: config.require("projectName"),
  });

  const vlan = new metal.Vlan("main", {
    facility: metal.Facility.AM6,
    projectId: project.id,
  });

  const device = new metal.Device("tinkerbell", {
    hostname: "tinkerbell",
    plan: metal.Plan.C3MediumX86,
    metro: "am",
    operatingSystem: metal.OperatingSystem.Ubuntu2004,
    billingCycle: metal.BillingCycle.Hourly,
    projectId: project.id,
    userData: `#!/usr/bin/env sh
git clone https://github.com/rawkode/tinkerbell-on-equinix-metal /opt/
sh /opt/tinkerbell-on-equinix-metal/saltstack/bootstrap.sh
`,
  });

  const deviceNetworkType = new metal.DeviceNetworkType("tinkerbell", {
    deviceId: device.id,
    type: metal.NetworkType.Hybrid,
  });

  const portVlanAttachment = new metal.PortVlanAttachment(
    "tinkerbell",
    {
      deviceId: device.id,
      portName: "eth1",
      vlanVnid: vlan.vxlan,
    },
    {
      dependsOn: [deviceNetworkType],
    }
  );
};
