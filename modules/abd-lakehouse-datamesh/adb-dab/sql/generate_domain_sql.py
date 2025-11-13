#!/usr/bin/env python3
"""
Generate domain-specific Unity Catalog SQL scripts.

This script reads the template SQL file and replaces the domain name,
allowing you to quickly create catalog setup scripts for different business domains.

Usage:
    python generate_domain_sql.py --domain finance
    python generate_domain_sql.py --domain sales --output sales_uc_setup.sql
"""

import argparse
import sys
from pathlib import Path


def generate_domain_sql(template_path: str, domain: str, output_path: str | None = None) -> str:
    """
    Generate a domain-specific SQL script from the template.
    
    Args:
        template_path: Path to the template SQL file
        domain: Domain name (e.g., 'finance', 'sales', 'hr')
        output_path: Optional output file path. If None, prints to stdout.
    
    Returns:
        Generated SQL content
    """
    # Read template file
    template_file = Path(template_path)
    if not template_file.exists():
        raise FileNotFoundError(f"Template file not found: {template_path}")
    
    template_content = template_file.read_text(encoding='utf-8')
    
    # Replace domain name (case-sensitive replacements)
    # Assuming template uses 'amrnet' as the default domain
    sql_content = template_content.replace('amrnet', domain.lower())
    sql_content = sql_content.replace('AMRNet', domain.upper())
    sql_content = sql_content.replace('Amrnet', domain.capitalize())
    
    # Update the configuration comment
    config_line = f"--   Domain: {domain.lower()}"
    sql_content = sql_content.replace("--   Domain: amrnet", config_line)
    
    # Write to output file or print to stdout
    if output_path:
        output_file = Path(output_path)
        output_file.write_text(sql_content, encoding='utf-8')
        print(f"✅ Generated SQL script for '{domain}' domain: {output_path}")
    else:
        print(sql_content)
    
    return sql_content


def main():
    parser = argparse.ArgumentParser(
        description='Generate domain-specific Unity Catalog SQL scripts',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate SQL for finance domain (print to stdout)
  python generate_domain_sql.py --domain finance
  
  # Generate SQL for sales domain and save to file
  python generate_domain_sql.py --domain sales --output sales-uc-setup.sql
  
  # Generate SQL using a custom template
  python generate_domain_sql.py --domain hr --template custom-template.sql --output hr-uc-setup.sql
        """
    )
    
    parser.add_argument(
        '--domain',
        required=True,
        help='Domain name (e.g., finance, sales, hr, marketing)'
    )
    
    parser.add_argument(
        '--template',
        default='uc-roles-grants.sql',
        help='Path to the template SQL file (default: uc-roles-grants.sql)'
    )
    
    parser.add_argument(
        '--output',
        '-o',
        help='Output file path. If not specified, prints to stdout.'
    )
    
    args = parser.parse_args()
    
    try:
        generate_domain_sql(
            template_path=args.template,
            domain=args.domain,
            output_path=args.output
        )
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
