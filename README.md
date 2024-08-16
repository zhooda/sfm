# sfm

Basic command line interface for interacting with the [Shadeform](https://shadeform.ai) API.

I used the comand + subcommand style from the AWS CLI since it's what I use most often. The API client `Client{}` (from `src/shadeform.zig`) is fairly atomic but watch out for longer-lived memory bugs from JSON serde.

## Installation

**Note:** I have no idea if this will compile or run on Windows but it should be fine under WSL.

Build it from source, I doubt this tool will live long enough to justify spending effort on automated builds:

``` shell
git clone https://github.com/zhooda/sfm && cd sfm
zig build -Doptimize=ReleaseSafe
```

Install somewhere in your path: 

``` shell
install -m755 ./sfm /usr/local/bin/sfm
```

This works on Mac, not sure if it's POSIX compliant though. Read the man page for your system (`man 1 install`).

## Usage

Set the `SHADEFORM_API_KEY` environment variable to your API key:

``` shell
# bash/zsh
echo 'export SHADEFORM_API_KEY="[YOUR_KEY_HERE]"' >> ~/.profile
source ~/.profile
# fish
set -Ux SHADEFORM_API_KEY "[YOUR_KEY_HERE]"
```

**Note:** Only listing instances and instance types is currently implemented.

### Instances

``` shell
# list all active and pending instances
sfm instances list
# list all instance types
sfm instances list-types
```

## Notes

- Command line parsing can panic sometimes
- Memory bugs probably exist where JSON serde is used (`std.json.parseFromSliceLeaky`)
- Poor cache-line locality (SoA pattern of `std.MultiArrayList` may help here)

## References

1. [Shadeform API Documentation](https://docs.shadeform.ai/api-reference/)
2. [Zigcli - Simargs](https://zigcli.liujiacai.net/docs/modules/simargs/) - Command line parsing
3. [Zig Cookbook](https://cookbook.ziglang.cc/10-01-json.html) - JSON deserialization

