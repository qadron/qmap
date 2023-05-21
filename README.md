# Qmap

QMap is a distributed network mapper/security scanner backed by:

* [Cuboid](https://github.com/qadron/cuboid) for the distributed architecture.
* [nmap](https://nmap.org/) for the scanning engine.
* [ruby-nmap](https://github.com/postmodern/ruby-nmap) for the Ruby middleware.

Its basic function is to distribute the scanning of IP ranges across multiple machines and thus parallelize an otherwise 
quite time consuming task.

## Installation

Install the gem by executing:

    $ gem install qmap

## Usage

CLI interface is on its way, for now see the `examples/` directory.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/qadron/qmap.

## Funding

QMap is a [Qadron](https://github.com/qadron/) project and as such funded by [Ecsypno Single Member P.C.](https://ecsypno.com).
