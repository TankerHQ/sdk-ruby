from typing import Optional
import argparse
import os
from pathlib import Path
import sys


import tankerci
import tankerci.bump
import tankerci.conan
import tankerci.git
import tankerci.gitlab
from tankerci.conan import TankerSource


def prepare(
    tanker_source: TankerSource,
    profile: str,
    update: bool,
    tanker_ref: Optional[str],
) -> None:
    tanker_deployed_ref = tanker_ref
    if tanker_source == TankerSource.DEPLOYED and not tanker_deployed_ref:
        tanker_deployed_ref = "tanker/latest-stable@"
    tankerci.conan.install_tanker_source(
        tanker_source,
        output_path=Path.cwd() / "conan",
        profiles=[profile],
        tanker_deployed_ref=tanker_deployed_ref,
    )


def build_and_test(
    tanker_source: TankerSource, profile: str, tanker_ref: Optional[str]
) -> None:
    prepare(tanker_source, profile, False, tanker_ref)
    tankerci.run("bundle", "install")
    tankerci.run("bundle", "exec", "rake", "spec")


def lint() -> None:
    tankerci.run("bundle", "install")
    tankerci.run("bundle", "exec", "rake", "rubocop")


def deploy(version: str) -> None:
    expected_libs = [
        "vendor/tanker/linux-x86_64/libctanker.so",
        "vendor/tanker/darwin-x86_64/libctanker.dylib",
    ]
    for lib in expected_libs:
        expected_path = Path(lib)
        if not expected_path.exists():
            sys.exit(f"Error: {expected_path} does not exist!")

    tankerci.bump.bump_files(version)

    # Note: this commands also re-gerenates the lock as a side-effect since the
    # gemspec has changed - keep this before the git commands
    tankerci.run("bundle", "install")

    # Note: `bundle exec rake build` does not like dirty git repos, so make a
    # commit with the new changes first
    tankerci.git.run(Path.cwd(), "add", "--update", ".")
    tankerci.git.run(Path.cwd(), "commit", "--message", f"Bump to {version}")
    tankerci.run("bundle", "exec", "rake", "build")
    tankerci.run("bundle", "exec", "rake", "push")


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
        "--use-tanker",
        type=TankerSource,
        default=TankerSource.EDITABLE,
        dest="tanker_source",
    )
    build_and_test_parser.add_argument("--profile", default="default")
    build_and_test_parser.add_argument("--tanker-ref")

    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument(
        "--use-tanker",
        type=TankerSource,
        default=TankerSource.EDITABLE,
        dest="tanker_source",
    )
    prepare_parser.add_argument("--profile", default="default")
    prepare_parser.add_argument("--tanker-ref")
    prepare_parser.add_argument(
        "--update",
        action="store_true",
        default=False,
        dest="update",
    )

    reset_branch_parser = subparsers.add_parser("reset-branch")
    reset_branch_parser.add_argument("branch")

    download_artifacts_parser = subparsers.add_parser("download-artifacts")
    download_artifacts_parser.add_argument("--project-id", required=True)
    download_artifacts_parser.add_argument("--pipeline-id", required=True)
    download_artifacts_parser.add_argument("--job-name", required=True)

    deploy_parser = subparsers.add_parser("deploy")
    deploy_parser.add_argument("--version", required=True)
    subparsers.add_parser("lint")
    subparsers.add_parser("mirror")

    args = parser.parse_args()
    command = args.command

    if args.home_isolation:
        tankerci.conan.set_home_isolation()
        tankerci.conan.update_config()
        if command == "build-and-test":
            # Because of GitLab issue https://gitlab.com/gitlab-org/gitlab/-/issues/254323
            # the downstream deploy jobs will be triggered even if upstream has failed
            # By removing the cache we ensure that we do not use a
            # previously built (and potentially broken) release candidate to deploy a binding
            tankerci.conan.run("remove", "tanker/*", "--force")

    if command == "build-and-test":
        build_and_test(args.tanker_source, args.profile, args.tanker_ref)
    elif command == "prepare":
        prepare(
            args.tanker_source,
            args.profile,
            args.update,
            args.tanker_ref,
        )
    elif command == "deploy":
        deploy(args.version)
    elif command == "lint":
        lint()
    elif command == "reset-branch":
        fallback = os.environ["CI_COMMIT_REF_NAME"]
        ref = tankerci.git.find_ref(
            Path.cwd(), [f"origin/{args.branch}", f"origin/{fallback}"]
        )
        tankerci.git.reset(Path.cwd(), ref)
    elif command == "download-artifacts":
        tankerci.gitlab.download_artifacts(
            project_id=args.project_id,
            pipeline_id=args.pipeline_id,
            job_name=args.job_name,
        )
    elif args.command == "mirror":
        tankerci.git.mirror(github_url="git@github.com:TankerHQ/sdk-ruby")
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
