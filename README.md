# Gekko Deployment on EC2

## Installing the Scripts

One needs to install these:

- the Ruby 1.9 programming language
- [Amazon's EC2 API Tools](http://aws.amazon.com/developertools/351)
- [Amazon's Elastic Load Balancing Tools](http://aws.amazon.com/developertools/2536)
- [Amazon's CloudWatch Tools](http://aws.amazon.com/developertools/2534)
- [Amazon's Autoscaling Tools](http://aws.amazon.com/developertools/2535)

Installation under Ubuntu:

```bash
sudo aptitude install ruby1.9.1 ec2-api-tools elbcli moncli ascli
```

You need access credentials (a pair of Access/Secret keys). For lack
of one, go to
[Security Credentials](https://portal.aws.amazon.com/gp/aws/securityCredentials)
in the Amazon Account and generate a pair. Then set the following
environment variables, either in `$HOME/.profile` or
`$HOME/.bash_profile`, like so:

```bash
export AWS_ACCESS_KEY="xxxxxx"
export AWS_SECRET_KEY="yyyyyy"
export AWS_CREDENTIAL_FILE="$HOME/.ssh/aws-credentials"
```

Edit the file `$HOME/.ssh/aws-credentials` adding the following lines:

```
AWSAccessKeyId=xxxxx
AWSSecretKey=yyyyy
```

This access key is used by Amazon's tools for authentication. You also
need an SSH certificate that the scripts (and you) will use for
connecting to the EC2 instances.

Alex already has a gekko.pem generated, so ask him, otherwise to
deploy without it go to the
[EC2 Key Pairs](https://console.aws.amazon.com/ec2/home?region=us-east-1#s=KeyPairs)
section, generate one and copy it to your "$HOME/.ssh" directory. This
file that Amazon gives you is an SSH private key that will be used in
SSH connections, so make it available only to your local user (it
doesn't have to be named `gekko.pem`, you just have to remember its
path for later):

```
chmod +x $HOME/.ssh/gekko.pem
```

Do a quick check:

```
bin/list_snapshots.rb
```

## Deployment Procedure

### Step 1: Creating a New Snapshot

A snapshot is an AMI ([machine image](https://aws.amazon.com/amis/))
with an attached
[auto-scaling group](http://aws.amazon.com/autoscaling/) configuration.

This AMI gets created from the latest code on Git and will be named by
default like so:

```
gekko-20130412-144703
```

Noticed it is prefixed with `gekko` and contains the timestamp. It
contains everything needed to start new preconfigured instances, with
a snapshot of the application at the indicated timestamp.

To create a new snapshot with the latest config and latest code pushed
to [Gekko's master](https://github.com/epigrams/gekko) do this:

```
bin/create_snapshot.rb -k gekko -i ~/.ssh/gekko.pem
```

The above command takes as parameters the key-pair name and the path
to the pem file associated with that name.

The output of this script, if everything goes well, is going to be a
fully configured AMI and an associated auto-scalling launch script.
At the end, for deployment, you only need the name of the created
snapshot.

Or later, to view the available snapshots:

```
bin/list_snapshots.rb
```

### Step 2: Deploying a Snapshot in Production

To deploy an auto-scaling group related to a snapshot, do this:

```bash
bin/deploy_snapshot.rb -s gekko-20130419-144627 \
  --min-size 2 \
  --max-size 6 \
  --desired-capacity 1
```

The name of the created auto-scaling group is going to match the name
of the snapshot, so according to the above example that would be
`gekko-20130419-144627`. So you can use it with Amazon's tools, for
instance to check its state:

```bash
as-describe-auto-scaling-groups gekko-20130419-144627
```

### Step 3: Leave it running for 24 hours

Leave the deployed snapshot running for 24 hours. It will run
side-by-side with the old snapshot and the load balancer will
distribute trafic between the old version and the new version.

### Step 4: If everything went well, pull the old snapshot from ELB

First, update the deployed snapshot you want to leave on with the
production parameters:

```bash
bin/update_deployed_snapshot.rb -s gekko-20130419-144627 \
  --min-size 8 \
  --max-size 20 \
  --desired-capacity 14
```

Wait until the new instances have been created and leave them running
for another 30 minutes, giving them a chance to warm up.

Check the state of the auto-scaling group to see if the instances have
been created:

```bash
as-describe-auto-scaling-groups gekko-20130419-144627
```

Check the state of ELB to see if the new instances are considered
healthy (note, the load balancer's name is the same `gekko` and not
the name of the snapshot):

```bash
elb-describe-instance-health gekko
```

Then destroy the old auto-scaling group:

```bash
as-delete-auto-scaling-group gekko-20130418-162809 --force --force-delete
```

That's it.

## Further Development

Under heavy load Linux networking needs to be tweaked. Some documents
I found that address issues:

* http://fasterdata.es.net/host-tuning/linux/
* http://jira.codehaus.org/browse/JETTY-1505
* http://docs.codehaus.org/display/JETTY/HighLoadServers

These options need investigation.