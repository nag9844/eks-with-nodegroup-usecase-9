# policy/s3_public_access.rego
package terraform.aws.s3

# Default to allow
default allow = true

# Deny if any S3 bucket has public-read or public-read-write ACL
deny {
  some i
  resource := input.resource_changes[i]
  resource.type == "aws_s3_bucket"
  resource.change.after.acl == "public-read"
}

deny {
  some i
  resource := input.resource_changes[i]
  resource.type == "aws_s3_bucket"
  resource.change.after.acl == "public-read-write"
}

# Provide a message for the denial
deny_message = "S3 bucket '%s' has a public ACL set (%s). Public access is not allowed." {
  some i
  resource := input.resource_changes[i]
  resource.type == "aws_s3_bucket"
  resource.change.after.acl == "public-read"
  bucket_name := resource.change.after.bucket
  acl := resource.change.after.acl
  sprintf(deny_message, ["S3 bucket '%s' has a public ACL set (%s). Public access is not allowed.", bucket_name, acl])
}

deny_message = "S3 bucket '%s' has a public ACL set (%s). Public access is not allowed." {
  some i
  resource := input.resource_changes[i]
  resource.type == "aws_s3_bucket"
  resource.change.after.acl == "public-read-write"
  bucket_name := resource.change.after.bucket
  acl := resource.change.after.acl
  sprintf(deny_message, ["S3 bucket '%s' has a public ACL set (%s). Public access is not allowed.", bucket_name, acl])
}