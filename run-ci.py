from typing import Any
import argparse
import sys

from path import Path

import ci
import ci.conan
import ci.git

DEPLOYED_TANKER = "tanker/2.4.1@tanker/stable"
LOCAL_TANKER = "tanker/dev@tanker/dev"


class Builder:
    def __init__(self, *, src_path: Path, tanker_conan_ref: str):
        self.src_path = src_path
        self.tanker_conan_ref = tanker_conan_ref

    def get_build_path(self) -> Path:
        build_path = self.src_path / "vendor/libctanker/linux64"
        build_path.makedirs_p()
        return build_path

    def install_sdk_native(self, *, profile: str) -> None:
        install_path = self.get_build_path()
        # fmt: off
        ci.conan.run(
            "install", self.tanker_conan_ref,
            "--update",
            "--profile", profile,
            "--options", "tanker:tankerlib_shared=True",
            "--install-folder", install_path,
            "--generator", "deploy"
        )
        # fmt: on

    def install_ruby_deps(self):
        with self.src_path:
            ci.run("bundle", "install")

    def test(self) -> None:
        with self.src_path:
            ci.run("bundle", "exec", "rake", "spec")

    def lint(self) -> None:
        with self.src_path:
            ci.run("bundle", "exec", "rake", "rubocop")

    def deploy(self) -> None:
        with self.src_path:
            ci.run("bundle", "exec", "rake", "build")
            ci.run("bundle", "exec", "rake", "push")


def create_builder(args: Any) -> Builder:
    src_path = Path.getcwd()

    if args.use_tanker == "deployed":
        tanker_conan_ref = DEPLOYED_TANKER
    elif args.use_tanker == "local":
        tanker_conan_ref = LOCAL_TANKER
        ci.conan.export(
            src_path=Path.getcwd().parent / "sdk-native", ref_or_channel="tanker/dev"
        )
    elif args.use_tanker == "same-as-branch":
        tanker_conan_ref = LOCAL_TANKER
        workspace = ci.git.prepare_sources(repos=["sdk-native", "sdk-ruby"])
        src_path = workspace / "sdk-ruby"
        ci.conan.export(src_path=workspace / "sdk-native", ref_or_channel="tanker/dev")
    else:
        raise RuntimeError("invalid argument")

    builder = Builder(src_path=src_path, tanker_conan_ref=tanker_conan_ref)
    return builder


def build_and_test(args: Any) -> None:
    builder = create_builder(args)
    builder.install_ruby_deps()
    builder.install_sdk_native(profile=args.profile)
    builder.test()


def lint(args: Any) -> None:
    builder = create_builder(args)
    builder.install_ruby_deps()
    builder.lint()


def deploy(args: Any) -> None:
    builder = create_builder(args)
    builder.install_ruby_deps()
    builder.install_sdk_native(profile=args.profile)
    builder.test()
    builder.deploy()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--isolate-conan-user-home",
        action="store_true",
        dest="home_isolation",
        default=False,
    )

    subparsers = parser.add_subparsers(title="subcommands", dest="command")

    build_and_test_parser = subparsers.add_parser("build-and-test")
    build_and_test_parser.add_argument(
        "--use-tanker", choices=["deployed", "local", "same-as-branch"], default="local"
    )
    build_and_test_parser.add_argument("--profile", default="default")

    deploy_parser = subparsers.add_parser("deploy")
    deploy_parser.add_argument("--profile", required=True)
    deploy_parser.set_defaults(use_tanker="deployed")

    lint_parser = subparsers.add_parser("lint")
    lint_parser.set_defaults(use_tanker="deployed")
    lint_parser.set_defaults(profile="default")

    args = parser.parse_args()

    if args.home_isolation:
        ci.conan.set_home_isolation()
        ci.conan.update_config()

    command = args.command
    if command == "build-and-test":
        build_and_test(args)
    elif command == "deploy":
        args.use_tanker = "deployed"
        deploy(args)
    elif command == "lint":
        lint(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
