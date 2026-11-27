FROM python:3.13-slim-trixie@sha256:7249d5587b78209a006dc4a3b5340678f84ea729239193aa559962cd8c1fce50 AS python_runtime
FROM dart:3.12.0@sha256:1bc3667e7e5d647bf0f00d62673790b06719ba39e108776a7cc3529887e81fb7
COPY --from=python_runtime /usr/local /usr/local
LABEL org.opencontainers.image.revision="f6563f6858b1b9d0b1db8071c0e645ea510aea24"
LABEL org.nebula.ci.source-tree="e3c08b02c4de9108ac056773543fba95a359045c"
ENV PUB_CACHE=/opt/nebula-pub-cache
COPY governance/ci_dependency_snapshot.json /opt/nebula-ci/dependency-snapshot.json
COPY ci/images/nebula-sdk/cache/ /opt/nebula-pub-cache/
RUN python3 -c "$(printf '%s\n' \
  'from pathlib import Path' \
  'import json,hashlib,re' \
  's=json.loads(Path('"'"'/opt/nebula-ci/dependency-snapshot.json'"'"').read_text())' \
  'packages=s['"'"'packages'"'"']' \
  'hosted=s['"'"'package_hosted_sha256'"'"']' \
  'trees=s['"'"'package_cache_tree_sha256'"'"']' \
  'assert len(packages)==47 and set(packages)==set(hosted)==set(trees)' \
  'assert s['"'"'dart_version'"'"']=='"'"'3.12.0'"'"'' \
  'assert s['"'"'image_identity'"'"']=='"'"'nebula-sdk-ci-candidate-20261127-v2'"'"'' \
  'assert s['"'"'source_dev_integration_sha'"'"']=='"'"'f6563f6858b1b9d0b1db8071c0e645ea510aea24'"'"'' \
  'assert s['"'"'source_dev_integration_tree_sha'"'"']=='"'"'e3c08b02c4de9108ac056773543fba95a359045c'"'"'' \
  'cache=Path('"'"'/opt/nebula-pub-cache'"'"')' \
  'hosted_dir=cache/'"'"'hosted/pub.dev'"'"'' \
  'hash_dir=cache/'"'"'hosted-hashes/pub.dev'"'"'' \
  'expected_stems={name+'"'"'-'"'"'+version for name,version in packages.items()}' \
  'assert {x.name for x in hosted_dir.iterdir()}==expected_stems,'"'"'wrong package directory names'"'"'' \
  'assert {x.name for x in hash_dir.iterdir()}=={s+'"'"'.sha256'"'"' for s in expected_stems},'"'"'wrong hosted SHA filenames'"'"'' \
  files_checked=0 \
  'for name,version in sorted(packages.items()):' \
  '    stem=name+'"'"'-'"'"'+version' \
  '    checksum=hosted[name]' \
  '    assert re.fullmatch(r'"'"'[0-9a-f]{64}'"'"',checksum),'"'"'invalid package hosted SHA256'"'"'' \
  '    checksum_file=hash_dir/(stem+'"'"'.sha256'"'"')' \
  '    assert checksum_file.is_file() and not checksum_file.is_symlink() and checksum_file.read_text().strip()==checksum,'"'"'mismatched hosted SHA: '"'"'+stem' \
  '    base=hosted_dir/stem' \
  '    assert base.is_dir() and not base.is_symlink(),'"'"'missing package cache: '"'"'+stem' \
  '    fs=[]' \
  '    for f in base.rglob('"'"'*'"'"'):' \
  '        assert not f.is_symlink(),'"'"'symlink in cache: '"'"'+stem' \
  '        if f.is_file():fs.append(f)' \
  '        elif not f.is_dir():raise RuntimeError('"'"'non-file entry in '"'"'+stem)' \
  '    digest=hashlib.sha256()' \
  '    for f in sorted(fs,key=lambda x:x.relative_to(base).as_posix()):' \
  '        rel=f.relative_to(base).as_posix()' \
  '        digest.update(rel.encode('"'"'utf-8'"'"')+bytes([0])+hashlib.sha256(f.read_bytes()).hexdigest().encode('"'"'ascii'"'"')+bytes([10]))' \
  '        files_checked+=1' \
  '    assert digest.hexdigest()==trees[name],'"'"'package content changed: '"'"'+stem' \
  'print('"'"'CI_PACKAGE_HASH_GUARD_PASS packages='"'"'+str(len(packages))+'"'"' files='"'"'+str(files_checked))' \
)"
RUN echo 'nebula-sdk-ci-candidate-20261127-v2' > /opt/nebula-sdk-ci-id && python3 --version && dart --version
WORKDIR /workspace
