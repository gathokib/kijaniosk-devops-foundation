# IAM Least Privilege

## Application Task

The KijaniKiosk application needs to store and retrieve objects from a specific Amazon S3 bucket used for application data.

## IAM Role

An IAM role should be assigned to the application rather than using long-term access keys.

The role should only allow the application to:

- Read objects from the KijaniKiosk S3 bucket.
- Upload objects to the KijaniKiosk S3 bucket.

## Example Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::kijaniosk-data/*"
    }
  ]
}
