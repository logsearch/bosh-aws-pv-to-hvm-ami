The `convert.sh` runs the following steps and, once complete, you're able to reference the new HVM-friendly stemcell in your deployment manifests. The script...

 0. starts a PV instance from the supplied PV AMI
 0. starts a HVM instance from the Amazon Linux
 0. stops the PV instance
 0. stops the HVM instance
 0. replaces the HVM root disk with the PV root disk
 0. creates a new image from the HVM instance
 0. destroys the temporary instances and disks
 0. downloads and patches the light-bosh stemcell
 0. uploads the patched stemcell to S3
 0. uploads the patched stemcell to bosh

The whole process typically takes just under 3 minutes.


## Usage

The `convert.sh` script requires four arguments (and the AWS_KEYPAIR_NAME env to be set):

 * the PV AMI (from `bosh stemcells`)
 * the correlating light-bosh stemcell (from `bosh public stemcells --full`)
 * the S3 bucket for uploading the patched stemcell
 * the S3 key for uploading the patched stemcell

Example:

    AWS_KEYPAIR_NAME=labs-commander ./convert.sh \
        ami-2f05c558 \
        https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/light-bosh-stemcell-2549-aws-xen-ubuntu-trusty-go_agent.tgz \
        ci-logsearch \
        bosh-stemcell/aws/light-bosh-stemcell-2549-aws-xen-ubuntu-trusty-go_agent-hvm.tgz 


Notes:

 * this utilizes the [`awscli`](http://aws.amazon.com/cli/) - make sure it's installed and your AWS credentials are available to it
 * the PV AMI is specific to your bosh deployment (you'll need to replace the first argument in the example for it to work for you)
 * if an error occurs, the script will fail and you'll need to manually clean up resources (resource IDs are output as they are created)
 * the patched light-bosh stemcell is uploaded to S3 with the `public-read` acl
 * this is a naive conversion process - this does not deal with OS or kernel changes to fully take advantage of HVM virtualization


## License

Copyright 2014 City Index Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
